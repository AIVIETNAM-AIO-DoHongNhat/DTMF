function bank = design_bpf_bank(opt)
%DESIGN_BPF_BANK Nạp/thiết kế ngân hàng 8 bộ lọc thông dải hẹp cho DTMF.
%   BANK = DESIGN_BPF_BANK() nạp hệ số bộ lọc từ file mặc định; nếu file
%   không tồn tại thì tự thiết kế theo công thức bộ cộng hưởng dự phòng.
%
%   BANK = DESIGN_BPF_BANK(Name, Value) thay đổi tham số qua các cặp
%   tên–giá trị.
%
%   Tham số tên–giá trị (mặc định trong ngoặc):
%       'fs'     - tần số lấy mẫu [Hz] (8000).
%       'coeffs' - đường dẫn file hệ số do tổ S3 xuất bằng filterDesigner,
%                  Gói đặc tả #5 ('data/mat/coeffs.mat'). Đường dẫn tương
%                  đối được tính từ thư mục làm việc hiện hành (pwd).
%       'r'      - bán kính cực của bộ cộng hưởng dự phòng, 0 < r < 1 (0.99).
%
%   Đầu ra:
%       bank - mảng struct 1×8 (7 tần số chuẩn + 1 bộ tại vị trí hài bậc 2),
%              mỗi phần tử gồm:
%           .f - tần số trung tâm [Hz].
%           .b - hệ số tử số (bộ lọc IIR bậc 2).
%           .a - hệ số mẫu số.
%
%   Công thức dự phòng (khi chưa có coeffs.mat) - bộ cộng hưởng bậc 2:
%       H(z) = G*(1 - z^-2) / (1 - 2*r*cos(w0)*z^-1 + r^2*z^-2),
%       w0   = 2*pi*f0/fs  [rad/mẫu].
%       - Hai điểm không tại z = ±1: triệt thành phần DC và fs/2.
%       - Hai cực tại z = r*exp(±j*w0): ổn định khi và chỉ khi r < 1.
%       - Băng thông -3 dB xấp xỉ BW ≈ (1 - r)*fs/pi [Hz];
%         với r = 0.99, fs = 8000 Hz: BW ≈ 25 Hz (khớp CONTRACTS.md).
%       - G chọn sao cho |H(exp(j*w0))| = 1 (độ lợi đơn vị tại f0).
%
%   Tham khảo:
%       [1] J. G. Proakis, D. G. Manolakis, Digital Signal Processing:
%           Principles, Algorithms, and Applications, 4th ed., Pearson,
%           2007 (mục bộ cộng hưởng số).
%       [2] Gói đặc tả #5 (tổ S3, filterDesigner) - xem CONTRACTS.md.
%
%   See also dtmf_decode_filterbank, filter.

arguments
    opt.fs (1,1) double = 8000
    opt.coeffs (1,:) char = 'data/mat/coeffs.mat'
    opt.r (1,1) double = 0.99
end

% TODO(C):
%   Ưu tiên 1: nếu isfile(opt.coeffs), nạp trực tiếp b/a của 8 bộ lọc do
%   tổ S3 cung cấp.
%   Dự phòng: tự tính theo công thức cộng hưởng ở trên cho 7 tần số chuẩn
%   [697 770 852 941 1209 1336 1477] Hz (+ 1 bộ tại vị trí hài nếu cần).

bank = struct('f', {}, 'b', {}, 'a', {}); %#ok<NASGU>
error('design_bpf_bank:notImplemented', 'TODO: cai dat design_bpf_bank (xem Goi dac ta #5).');

end
