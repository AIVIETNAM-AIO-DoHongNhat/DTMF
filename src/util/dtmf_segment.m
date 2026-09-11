function seg = dtmf_segment(y, opt)
%DTMF_SEGMENT Chia tín hiệu thành các khung để phân tích phổ.
%   SEG = DTMF_SEGMENT(Y) chia Y thành các khung không chồng lấp dài 205
%   mẫu.
%
%   SEG = DTMF_SEGMENT(Y, Name, Value) thay đổi tham số chia khung qua các
%   cặp tên–giá trị.
%
%   Đầu vào:
%       y - 1×N double, tín hiệu cần chia khung.
%
%   Tham số tên–giá trị (mặc định trong ngoặc):
%       'fs'     - tần số lấy mẫu [Hz] (8000).
%       'frameN' - độ dài khung [mẫu] (205); dùng 256 cho bộ giải mã FFT.
%       'hop'    - bước nhảy giữa hai khung liên tiếp [mẫu] (205).
%                  Mặc định cố định là 205, KHÔNG tự bằng frameN - khi đổi
%                  frameN thì phải truyền hop tương ứng.
%
%   Đầu ra:
%       seg - mảng struct 1×nFrame, mỗi phần tử gồm:
%           .idx    - [i1 i2], chỉ số mẫu đầu/cuối của khung trong y.
%           .tStart - thời điểm bắt đầu khung [s] (t = 0 tại y(1)).
%           .tEnd   - thời điểm kết thúc khung [s].
%
%   Số khung (khung cuối không đủ độ dài bị bỏ, không chèn 0):
%       nFrame = floor((N - frameN)/hop) + 1,  với N >= frameN;
%       khung thứ i: i1 = (i-1)*hop + 1,  i2 = i1 + frameN - 1.
%
%   Ghi chú:
%       Cả 3 bộ giải mã (FFT / Goertzel / ngân hàng bộ lọc) dùng CHUNG hàm
%       này để bảo đảm cùng một cách chia khung - không tự ý chia khung
%       riêng trong từng hàm giải mã.
%
%   See also dtmf_decode_fft, dtmf_decode_goertzel, dtmf_decode_filterbank.

arguments
    y (1,:) double
    opt.fs (1,1) double = 8000
    opt.frameN (1,1) double = 205
    opt.hop (1,1) double = 205
end

% TODO(C): trượt cửa sổ độ dài opt.frameN với bước opt.hop trên toàn bộ y.
% Khung cuối không đủ độ dài thì bỏ qua (không chèn 0 - zero-padding).

seg = struct('idx', {}, 'tStart', {}, 'tEnd', {}); %#ok<NASGU>
error('dtmf_segment:notImplemented', 'TODO: cai dat dtmf_segment.');

end
