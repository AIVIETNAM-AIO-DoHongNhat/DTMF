function bank = design_bpf_bank(opt)
%DESIGN_BPF_BANK Thiết kế ngân hàng bộ lọc IIR cộng hưởng cho DTMF
% Dựng 14 bộ lọc rất hẹp, mỗi bộ chỉ cho đúng một tần số DTMF đi qua
%   BANK = DESIGN_BPF_BANK() dựng ngân hàng với tham số mặc định.
%   BANK = DESIGN_BPF_BANK(Name, Value) đổi tham số qua cặp tên–giá trị.
%
%   Các bước hoạt động:
%       1. Nếu opt.coeffs tồn tại VÀ siêu dữ liệu trong file khớp fs/r/withHarm
%          đang yêu cầu thì nạp thẳng và dừng. Không khớp thì dựng lại bằng
%          công thức: file cũ KHÔNG bao giờ được dùng một cách im lặng.
%       2. Mỗi tần số f0 cho một bộ cộng hưởng bậc 2, w0 = 2*pi*f0/fs [rad/mẫu]:
%          H(z) = G*(1 - z^-2) / (1 - 2*r*cos(w0)*z^-1 + r^2*z^-2).
%          Hai điểm không tại z = ±1 triệt DC và fs/2; hai cực tại
%          z = r*exp(±j*w0) nên bộ lọc ổn định khi và chỉ khi r < 1.
%       3. freqz(b, a, f0, fs) đo |H(f0)|, rồi đặt G = 1/|H(f0)| để độ lợi tại
%          tâm bằng đúng 1 - nhờ vậy năng lượng đầu ra của 14 bộ cùng một thang.
%       4. withHarm = true thì dựng thêm 7 bộ tại tần số GẤP ĐÔI, xếp sau 7 bộ
%          chuẩn, phục vụ điều kiện hài bậc 2 của dtmf_decide (CONTRACTS §6(b)).
%
%   Tham số tên–giá trị (mặc định trong ngoặc):
%       'fs': tần số lấy mẫu [Hz] (8000).
%       'coeffs': đường dẫn file hệ số do scripts/make_coeffs.m sinh ra, tính
%                 từ thư mục làm việc hiện hành ('data/mat/coeffs.mat').
%       'r': bán kính cực, 0 < r < 1 (0.99). Băng thông -3 dB
%            BW ≈ (1-r)*fs/pi ≈ 25.5 Hz; thời hằng 5*tau = 62.2 ms < 100 ms
%            tone, đây là lý do r không lấy cao hơn.
%       'withHarm': true trả 14 bộ, false trả 7 bộ (true).
%
%   Output:
%       bank: mảng struct 1×14, hoặc 1×7 nếu withHarm = false. Mỗi phần tử có
%             .f tần số trung tâm [Hz], .b hệ số tử số, .a hệ số mẫu số.
%
%   Example:
%       bank = design_bpf_bank();
%       abs(freqz(bank(1).b, bank(1).a, bank(1).f, 8000))   % 1
arguments
    opt.fs (1,1) double = 8000
    opt.coeffs (1,:) char = 'data/mat/coeffs.mat'
    opt.r (1,1) double = 0.99
    opt.withHarm (1,1) logical = true
end

% Cực nằm ở bán kính r, nên r >= 1 đẩy cực lên/ra ngoài vòng tròn đơn vị và bộ
% lọc phân kỳ. filter() không báo gì, chỉ trả ra dãy số lớn dần - chặn tại nguồn.
if ~(opt.r > 0 && opt.r < 1)
    error('design_bpf_bank:unstableR', ...
        'r = %g; bán kính cực phải thỏa 0 < r < 1 để bộ lọc ổn định.', opt.r);
end

T  = dtmf_table();
f0 = [T.rowHz T.colHz];
if opt.withHarm
    f0 = [f0 2*f0];     % 7 bộ chuẩn trước, 7 bộ hài sau: bộ hài của j nằm ở 7+j
end

% Tần số hài gấp đôi nên dễ vượt Nyquist khi ai đó hạ fs. Ở fs = 8000 thì
% 2*1477 = 2954 < 4000, không chạm; hạ xuống fs = 4000 là gập phổ, và bộ lọc vẫn
% dựng ra bình thường với một tần số tâm SAI.
if max(f0) >= opt.fs/2
    error('design_bpf_bank:aboveNyquist', ...
        'Tần số tâm cao nhất %g Hz >= fs/2 = %g Hz.', max(f0), opt.fs/2);
end

nWant = numel(f0);

% Nhánh nạp - quyết định (b). Chỉ nhận file khi siêu dữ liệu khớp ĐÚNG tham số
% đang yêu cầu; lệch một trường thì bỏ qua và dựng lại. Thiếu chốt này, đổi r
% xong chạy lại vẫn ra hệ số cũ mà không một dấu hiệu nào.
if isfile(opt.coeffs)
    S = load(opt.coeffs);
    if isfield(S, 'bank') && isfield(S, 'meta') ...
            && isequal(S.meta.fs, opt.fs) ...
            && isequal(S.meta.r, opt.r) ...
            && isequal(S.meta.withHarm, opt.withHarm) ...
            && numel(S.bank) == nWant
        bank = S.bank;
        return
    end
end

bank = repmat(struct('f', 0, 'b', [0 0 0], 'a', [0 0 0]), 1, nWant);

for j = 1:nWant
    w0 = 2*pi*f0(j) / opt.fs;
    b  = [1 0 -1];                          % hai điểm không tại z = ±1
    a  = [1  -2*opt.r*cos(w0)  opt.r^2];    % hai cực tại z = r*exp(±j*w0)

    % freqz(b, a, f, fs) với f VÔ HƯỚNG bị hiểu là SỐ ĐIỂM chứ không phải tần
    % số - phải truyền vector rồi lấy phần tử đầu.
    H = freqz(b, a, [f0(j) f0(j)], opt.fs);

    bank(j).f = f0(j);
    bank(j).b = b / abs(H(1));              % G = 1/|H(f0)| -> độ lợi tâm bằng 1
    bank(j).a = a;
end

end
