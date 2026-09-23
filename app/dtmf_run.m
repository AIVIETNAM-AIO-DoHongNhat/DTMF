function S = dtmf_run(S)
%DTMF_RUN Chạy giải mã theo trạng thái S của ứng dụng, không vẽ gì
% Người bấm nút, hàm này chọn đúng bộ giải mã rồi dọn sẵn số liệu cho phần vẽ
%   S = DTMF_RUN(S) đọc S.y, S.fs, S.method rồi ghi kết quả ngược vào S.
%   Hàm này KHÔNG bao giờ ném lỗi: mọi sự cố được ghi vào S.lastError để giao
%   diện hiện lên nhật ký thay vì sập giữa buổi demo.
%
%   Các bước hoạt động:
%       1. Đặt lại năm trường đầu ra về giá trị rỗng hợp lệ. Thiếu bước này
%          thì lỗi của lần chạy trước còn treo lại sau một lần chạy thành công.
%       2. yd = S.y - mean(S.y) - BẮT BUỘC. Độ lệch một chiều 0.2 làm CẢ BA bộ
%          giải mã trả chuỗi rỗng; xem CONTRACTS §7.7. S.y KHÔNG bị ghi đè.
%       3. switch S.method gọi một trong ba bộ giải mã; tên lạ rơi vào nhánh
%          otherwise và thành thông báo lỗi, không thành ngoại lệ.
%       4. S.iSel = khung có conf lớn nhất, S.thr = 0.5*min(đỉnh hàng, đỉnh
%          cột) của khung đó - xem CONTRACTS §6(h). Không có khung nào thì cả
%          hai bằng 0 và ui_plot_bars xóa trục.
%
%   Đây là lớp trung gian DUY NHẤT giữa giao diện và src/. Mọi callback trong
%   DTMFApp chỉ gọi hàm này rồi gọi ui_refresh(app). Hàm này KHÔNG được vẽ và
%   không được phát âm thanh - luật §2.
%
%   Input:
%       S: struct trạng thái, cần .y (1×N double), .fs [Hz], .method
%          ('fft' | 'goertzel' | 'filterbank'). Danh sách đầy đủ các trường
%          của S nằm ở docs/ui_naming.md §4.
%
%   Output:
%       S: chính struct đó, với năm trường được ghi
%          .keysHat: char 1×K, chuỗi phím đọc được; 1×0 nếu không có.
%          .info: struct số liệu theo khung của bộ giải mã đã chọn.
%          .iSel: 1×1 double, chỉ số khung có conf lớn nhất; 0 nếu không có.
%          .thr: 1×1 double, ngưỡng vẽ cho ui_plot_bars.
%          .lastError: char, thông báo lỗi; rỗng là blanks(0) tức 1×0.
%
%   Example:
%       S = struct('y', dtmf_generate('59'), 'fs', 8000, 'method', 'fft');
%       S = dtmf_run(S);
%       S.keysHat       % '59'

% Bước 1. Cell rỗng phải bọc {} trong struct(), nếu không struct() coi nó là
% danh sách giá trị và trả về mảng struct rỗng thay vì một struct có trường.
S.keysHat   = blanks(0);
S.info      = struct('E',      zeros(8, 0), ...
                     'rowIdx', zeros(1, 0), ...
                     'colIdx', zeros(1, 0), ...
                     'conf',   zeros(1, 0), ...
                     'tFrame', zeros(1, 0), ...
                     'reject', {cell(1, 0)});
S.iSel      = 0;
S.thr       = 0;
S.lastError = blanks(0);

try
    % Bước 2. Trừ trung bình vào một biến TẠM. Ghi đè S.y thì ui_plot_wave vẽ
    % một tín hiệu khác với cái người dùng vừa sinh ra và vừa nghe.
    yd = S.y;
    if ~isempty(yd)
        yd = yd - mean(yd);
    end

    % Bước 3.
    switch S.method
        case 'fft'
            [S.keysHat, S.info] = dtmf_decode_fft(yd, 'fs', S.fs);
        case 'goertzel'
            [S.keysHat, S.info] = dtmf_decode_goertzel(yd, 'fs', S.fs);
        case 'filterbank'
            [S.keysHat, S.info] = dtmf_decode_filterbank(yd, 'fs', S.fs);
        otherwise
            % Không ném lỗi: một tên phương pháp sai là chuyện của giao diện,
            % không phải sự cố hệ thống.
            S.lastError = sprintf('method không hợp lệ: %s', string(S.method));
            return
    end

    % Bước 4.
    if ~isempty(S.info.conf)
        [~, S.iSel] = max(S.info.conf);
        E = S.info.E(:, S.iSel);
        S.thr = 0.5 * min(max(E(1:4)), max(E(5:7)));
    end
catch ME
    S.lastError = ME.message;
end

end
