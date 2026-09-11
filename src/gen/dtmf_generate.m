function [x, t, meta] = dtmf_generate(keys, opt)
%DTMF_GENERATE Tổng hợp tín hiệu DTMF từ chuỗi phím bấm.
%   [X, T, META] = DTMF_GENERATE(KEYS) sinh tín hiệu DTMF rời rạc cho
%   chuỗi phím KEYS với các tham số mặc định.
%
%   [X, T, META] = DTMF_GENERATE(KEYS, Name, Value) thay đổi tham số qua
%   các cặp tên–giá trị liệt kê dưới đây.
%
%   Đầu vào:
%       keys - char 1×K, chuỗi phím, ví dụ '0912345678*#'.
%
%   Tham số tên–giá trị (mặc định trong ngoặc):
%       'fs'      - tần số lấy mẫu [Hz] (8000).
%       'toneMs'  - thời lượng mỗi tone [ms] (100).
%       'pauseMs' - thời lượng khoảng lặng giữa hai phim liên tiếp [ms] (50).
%       'twistDb' - độ lệch mức cột so với hàng [dB] (0);
%                   > 0: cột mạnh hơn hàng (twist thuận).
%       'ampl'    - biên độ đỉnh sau chuẩn hóa, thuộc (0, 1] (0.5).
%
%   Đầu ra:
%       x    - 1×N double, tín hiệu DTMF, giá trị trong [-1, 1].
%       t    - 1×N double, trục thời gian tương ứng [s], t(1) = 0.
%       meta - struct mô tả nhãn thời gian:
%           .keys    - char 1×K, chuỗi phím đã sinh (= keys).
%           .onsets  - 1×K double, thời điểm bắt đầu mỗi tone [s].
%           .offsets - 1×K double, thời điểm kết thúc mỗi tone [s].
%           .fRow    - 1×K double, tần số hàng của từng phím [Hz].
%           .fCol    - 1×K double, tần số cột của từng phím [Hz].
%
%   Mô hình tín hiệu (phím thứ i, trong khoảng tone):
%       x_i(t) = sin(2*pi*fRow(i)*t) + g*sin(2*pi*fCol(i)*t),
%       g      = 10^(twistDb/20)   (hệ số khuếch đại biên độ của tone cột).
%
%   Ghi chú:
%       Tone 100 ms / nghỉ 50 ms là thông số chốt của dự án, đáp ứng yêu
%       cầu thời lượng tối thiểu của ITU-T Q.24 (xem CONTRACTS.md).
%
%   Tham khảo:
%       [1] ITU-T Rec. Q.23, "Technical features of push-button
%           telephone sets", 1988.
%       [2] ITU-T Rec. Q.24, "Multifrequency push-button signal
%           reception", 1988.
%       [3] Gói đặc tả #1 (tổ S1).
%
%   See also dtmf_table, dtmf_addnoise.

arguments
    keys (1,:) char
    opt.fs (1,1) double = 8000
    opt.toneMs (1,1) double = 100
    opt.pauseMs (1,1) double = 50
    opt.twistDb (1,1) double = 0
    opt.ampl (1,1) double = 0.5
end

% TODO(C):
%   1. T = dtmf_table(); tra cứu tần số hàng/cột cho từng ký tự trong keys.
%   2. Với mỗi phím: sinh đoạn sin(2*pi*fRow*t) + g*sin(2*pi*fCol*t),
%      với g = 10^(opt.twistDb/20) áp cho tone cột.
%      Nhân cửa sổ côn ngắn (ví dụ Tukey, tỉ lệ côn 5%) ở đầu/cuối mỗi
%      tone để tránh tiếng "click" do gián đoạn biên độ.
%   3. Chèn khoảng lặng dài opt.pauseMs giữa hai tone liên tiếp (không
%      chèn khoảng lặng trước tone đầu tiên, tức tại t = 0).
%   4. Ghép tất cả các đoạn thành x; chuẩn hóa để max(abs(x)) = opt.ampl.
%   5. Ghi onsets/offsets [s] và fRow/fCol [Hz] của từng phím vào meta.
%
%   LƯU Ý: hàm này KHÔNG được gọi figure/plot/disp/sound - chỉ trả dữ liệu.

x = [];      %#ok<NASGU>
t = [];      %#ok<NASGU>
meta = struct('keys', keys, 'onsets', [], 'offsets', [], 'fRow', [], 'fCol', []); %#ok<NASGU>

error('dtmf_generate:notImplemented', 'TODO: cai dat dtmf_generate (xem Goi dac ta #1).');

end
