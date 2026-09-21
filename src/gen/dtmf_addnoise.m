function y = dtmf_addnoise(x, opt)
%DTMF_ADDNOISE Cộng nhiễu vào tín hiệu DTMF theo SNR cho trước
% Làm bẩn tín hiệu sạch để thử độ bền của bộ giải mã
%   Y = DTMF_ADDNOISE(X) cộng nhiễu trắng Gauss với SNR = 10 dB.
%
%   Nhiễu thô v0 được nhân một hệ số để đạt đúng SNR mục tiêu:
%       v = v0 * sqrt(mean(x.^2) / (mean(v0.^2) * 10^(snrDb/10)))
%
%   Nhánh 'speech' đọc data/wav/speech_*.wav; thiếu file thì báo lỗi, KHÔNG
%   tự chuyển sang 'awgn'. Muốn tái lập nhiễu 'awgn', gọi rng(seed) trước.
%
%   Input:
%       x: 1×N double, tín hiệu sạch.
%
%   Tham số tên–giá trị (mặc định trong ngoặc):
%       'snrDb': tỉ số tín hiệu trên nhiễu [dB] (10).
%       'type': 'awgn' (Gauss trắng) | 'hum50' (sin 50 Hz) | 'speech'.
%       'fs': tần số lấy mẫu [Hz] (8000); cần cho 'hum50' và 'speech'.
%
%   Output:
%       y: 1×N double, y = x + v.
%
%   Example:
%       x = dtmf_generate('5');
%       y = dtmf_addnoise(x, 'snrDb', 10, 'type', 'awgn');
%       10*log10(sum(x.^2) / sum((y - x).^2))   % 10.0 (sai số < 0.5 dB)
arguments
    x (1,:) double
    opt.snrDb (1,1) double = 10
    opt.type (1,:) char {mustBeMember(opt.type, {'awgn','hum50','speech'})} = 'awgn'
    opt.fs (1,1) double = 8000
end

N = numel(x);
if N == 0
    y = x;
    return
end

%% 1. Sinh nhiễu thô - chỉ quan tâm dạng sóng, chưa quan tâm biên độ
switch opt.type
    case 'awgn'
        v0 = randn(1, N);               % mỗi mẫu độc lập, phổ phẳng

    case 'hum50'
        t  = (0:N-1) / opt.fs;
        v0 = sin(2*pi*50*t);            % ù điện lưới 50 Hz

    case 'speech'
        v0 = local_loadSpeech(N, opt.fs);
end

%% 2. Chuẩn hóa nhiễu về đúng SNR mục tiêu
% Từ SNR_dB = 10*log10(Px/Pv) suy ra Pv = Px / 10^(snrDb/10). Nhân v0 với
% căn của tỉ số công suất là ép được Pv về đúng giá trị đó.
Px  = mean(x.^2);
Pv0 = mean(v0.^2);

if Pv0 <= 0
    error('dtmf_addnoise:zeroNoise', ...
        'Nhiễu thô có công suất bằng 0, không chuẩn hóa theo SNR được.');
end

v = v0 * sqrt(Px / (Pv0 * 10^(opt.snrDb / 10)));
y = x + v;

end


function v0 = local_loadSpeech(N, fs)
%LOCAL_LOADSPEECH Đọc mẫu tiếng nói trong data/wav, lặp/cắt cho đủ N mẫu.

% Từ src/gen/dtmf_addnoise.m lùi 3 cấp về gốc repo.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
d = dir(fullfile(root, 'data', 'wav', 'speech_*.wav'));

if isempty(d)
    error('dtmf_addnoise:missingSpeech', ...
        ['Không tìm thấy data/wav/speech_*.wav. Hãy đặt file mẫu vào đó; ' ...
         'hàm KHÔNG tự chuyển sang nhiễu awgn.']);
end

[s, fsFile] = audioread(fullfile(d(1).folder, d(1).name));
s = s(:, 1).';                          % lấy kênh 1, đưa về vector hàng

if fsFile ~= fs
    error('dtmf_addnoise:speechFsMismatch', ...
        'File %s có fs = %g Hz, không khớp fs = %g Hz.', ...
        d(1).name, fsFile, fs);
end
if isempty(s)
    error('dtmf_addnoise:emptySpeech', ...
        'File %s không có mẫu nào.', d(1).name);
end

% Mẫu thoại thường ngắn hơn tín hiệu DTMF nên lặp lại cho đủ rồi cắt.
s  = repmat(s, 1, ceil(N / numel(s)));
v0 = s(1:N);

end
