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

% TODO(C):
%   1. Nếu isfile(opt.coeffs): nạp, kiểm siêu dữ liệu fs/r/withHarm; khớp thì
%      trả luôn, không khớp thì đi tiếp xuống bước 2.
%   2. Dựng 7 bộ cộng hưởng cho [697 770 852 941 1209 1336 1477] Hz theo công
%      thức trên, chuẩn hóa G bằng freqz.
%   3. withHarm thì dựng tiếp 7 bộ tại 2*f0, nối vào sau.

bank = struct('f', {}, 'b', {}, 'a', {}); %#ok<NASGU>
error('design_bpf_bank:notImplemented', 'TODO: cai dat design_bpf_bank (xem CONTRACTS muc 6b).');

end
