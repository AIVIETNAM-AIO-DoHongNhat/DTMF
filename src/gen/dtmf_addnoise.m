function y = dtmf_addnoise(x, opt)
%DTMF_ADDNOISE Cộng nhiễu vào tín hiệu DTMF theo SNR cho trước.
%   Y = DTMF_ADDNOISE(X) cộng nhiễu trắng Gauss (AWGN) với SNR = 10 dB.
%
%   Y = DTMF_ADDNOISE(X, Name, Value) chọn loại nhiễu và SNR qua các cặp
%   tên–giá trị. Dùng để kiểm thử độ bền của các bộ giải mã.
%
%   Đầu vào:
%       x - 1×N double, tín hiệu gốc (sạch).
%
%   Tham số tên–giá trị (mặc định trong ngoặc):
%       'snrDb' - tỉ số tín hiệu trên nhiễu mong muốn [dB] (10).
%       'type'  - loại nhiễu ('awgn'):
%                 'awgn'   - nhiễu trắng Gauss cộng tính;
%                 'hum50'  - nhiễu điện lưới, sin 50 Hz;
%                 'speech' - tín hiệu thoại mẫu (data/wav/speech_*.wav).
%       'fs'    - tần số lấy mẫu [Hz] (8000); cần cho 'hum50' và 'speech'.
%
%   Đầu ra:
%       y - 1×N double, tín hiệu đã cộng nhiễu, y = x + v.
%
%   Cơ sở lý thuyết:
%       SNR được định nghĩa theo công suất trung bình:
%           SNR_dB = 10*log10(Px / Pv),  Px = mean(x.^2),  Pv = mean(v.^2).
%       Để đạt SNR mục tiêu, nhiễu thô v0 được chuẩn hóa:
%           v = v0 * sqrt(Px / (mean(v0.^2) * 10^(snrDb/10))).
%
%   Ghi chú triển khai:
%       'awgn'   : dùng awgn(x, snrDb, 'measured') (cần Communications
%                  Toolbox) hoặc tự sinh randn rồi chuẩn hóa như trên.
%       'hum50'  : cộng sin(2*pi*50*t) đã chuẩn hóa theo SNR mục tiêu.
%       'speech' : cộng tín hiệu thoại mẫu đã chuẩn hóa theo SNR mục tiêu.
%
%   Tham khảo:
%       [1] Gói đặc tả #1 (tổ S1).
%
%   See also dtmf_generate, awgn.

arguments
    x (1,:) double
    opt.snrDb (1,1) double = 10
    opt.type (1,:) char {mustBeMember(opt.type, {'awgn','hum50','speech'})} = 'awgn'
    opt.fs (1,1) double = 8000
end

% TODO(C): cài đặt theo từng nhánh của opt.type (xem ghi chú triển khai).
% Kiểm chứng: SNR đo trên y phải khớp opt.snrDb với sai số ±0.5 dB,
% SNR_đo = 10*log10(sum(x.^2) / sum((y - x).^2)) - xem tests/test_generate.m.

y = x; %#ok<NASGU>
error('dtmf_addnoise:notImplemented', 'TODO: cai dat dtmf_addnoise (xem Goi dac ta #1).');

end
