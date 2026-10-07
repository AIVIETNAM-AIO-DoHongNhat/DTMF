function [x, info] = dtmf_readaudio(duongDan, opt)
%DTMF_READAUDIO Đọc một tệp âm thanh thành tín hiệu một kênh ở tần số lấy mẫu của bộ giải mã
% Lối vào "nhập từ file audio" của DTMFApp: tệp ghi âm thật, hoặc tệp WAV tải từ trang web
%   [X, INFO] = DTMF_READAUDIO(DUONGDAN) đọc tệp bằng audioread, lấy trung
%   bình các kênh, đổi về 8000 Hz rồi trả về X dạng hàng. Hàm NÉM LỖI khi
%   không đọc được tệp; DTMFApp bắt lỗi và ghi vào S.lastError.
%
%   Đây là lớp trung gian giữa giao diện và src/, cùng chỗ với dtmf_run và
%   dtmf_listen: giao diện chỉ gọi hàm này, không tự đổi tần số lấy mẫu.
%
%   Các bước hoạt động:
%       1. audioread trả N×C double trong [-1, 1], kể cả tệp số nguyên.
%       2. Trung bình C kênh thành một kênh: tệp stereo của điện thoại có hai
%          kênh gần như trùng nhau, lấy trung bình không làm lệch tần số.
%       3. Khác opt.fs thì resample (lọc chống chồng phổ có sẵn) về opt.fs.
%          Hạ tần số mà không lọc thì phần trên 4 kHz của tệp 44,1 kHz gập
%          xuống băng thoại và có thể rơi đúng vào tám bin DTMF.
%       4. Dài hơn opt.maxSec giây thì chỉ giữ phần đầu, để đồ thị và bộ
%          giải mã không treo giao diện với một tệp dài cả giờ.
%
%   Input:
%       duongDan: char hoặc string, đường dẫn tệp (wav, flac, ogg, mp3, m4a -
%                 tùy định dạng audioread trên máy hỗ trợ).
%       'fs':     tần số lấy mẫu đầu ra [Hz] (8000).
%       'maxSec': độ dài tối đa giữ lại [s] (60).
%
%   Output:
%       x: 1×N double, tín hiệu một kênh ở opt.fs.
%       info: struct 1×1
%          .fsFile:    tần số lấy mẫu của tệp [Hz].
%          .nChannel:  số kênh của tệp.
%          .fileSec:   độ dài tệp [s].
%          .truncated: true nếu đã cắt bớt theo opt.maxSec.
%
%   Example:
%       [x, info] = dtmf_readaudio('ban_phim.wav');
%       keys = dtmf_decode_goertzel(x - mean(x))
arguments
    duongDan (1,:) char
    opt.fs (1,1) double = 8000
    opt.maxSec (1,1) double = 60
end

% Bước 1
[y, fsTep] = audioread(duongDan);
info = struct('fsFile', fsTep, 'nChannel', size(y, 2), ...
              'fileSec', size(y, 1) / fsTep, 'truncated', false);
if isempty(y)
    error('dtmf_readaudio:empty', 'Tệp không có mẫu âm thanh nào.');
end

% Bước 2
y = mean(y, 2);

% Bước 3 - resample cần tỉ số nguyên; rat đổi tỉ số thực về p/q gần nhất.
if fsTep ~= opt.fs
    [p, q] = rat(opt.fs / fsTep, 1e-9);
    y = resample(y, p, q);
end
x = reshape(y, 1, []);

% Bước 4
nMax = round(opt.maxSec * opt.fs);
if numel(x) > nMax
    x = x(1:nMax);
    info.truncated = true;
end
end
