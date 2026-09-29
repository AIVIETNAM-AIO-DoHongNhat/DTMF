function [rec, loi] = ui_mic(fs)
%UI_MIC Mở micro mặc định của máy, trả về rỗng kèm lý do thay vì ném lỗi
% Lấy "cái tai" cho hai chế độ ghi âm và nghe trực tiếp của DTMFApp
%   [REC, LOI] = UI_MIC(FS) dựng audiorecorder đơn kênh 16 bit ở tần số lấy
%   mẫu FS, CHƯA bắt đầu ghi. Máy không có micro, hoặc driver từ chối FS, thì
%   REC = [] và LOI là một câu giải thích để ghi vào nhật ký.
%
%   Các bước hoạt động:
%       1. audiodevinfo(1) = 0: máy không có thiết bị thu nào.
%       2. audiorecorder(fs, 16, 1) bọc try/catch. Phòng máy khóa micro, quyền
%          truy cập micro của Windows đang tắt, hay tai nghe vừa rút đều ném
%          lỗi ở đây; một buổi demo không được sập chỉ vì cái micro.
%
%   Dùng audiorecorder của MATLAB gốc, KHÔNG dùng audioDeviceReader: cái sau
%   thuộc Audio Toolbox, mà dự án chỉ được phụ thuộc Signal Processing Toolbox
%   (CONTRACTS §3). audiorecorder cho đọc dữ liệu ngay trong lúc đang ghi
%   (getaudiodata) và gọi TimerFcn định kỳ - đủ cho giải mã theo luồng.
%
%   Giống ui_play, hàm này KHÔNG tự chặn chế độ chạy ẩn: quyết định "giao diện
%   ẩn thì không đụng thiết bị âm thanh" nằm ở DTMFApp.
%
%   Input:
%       fs: 1×1 double, tần số lấy mẫu [Hz].
%
%   Output:
%       rec: audiorecorder, hoặc [] nếu không mở được micro.
%       loi: char, lý do không mở được; rỗng là blanks(0) tức 1×0.
%
%   Example:
%       [rec, loi] = ui_mic(8000);
%       isempty(rec)    % true nếu máy không có micro, xem loi

rec = [];
loi = blanks(0);

% Bước 1.
try
    nThu = audiodevinfo(1);
catch
    nThu = 0;
end
if nThu == 0
    loi = 'Không tìm thấy micro nào trên máy.';
    return
end

% Bước 2.
try
    rec = audiorecorder(fs, 16, 1);
catch ME
    rec = [];
    loi = sprintf('Không mở được micro: %s', ME.message);
end

end
