function T = dtmf_table()
%DTMF_TABLE Bảng tần số chuẩn DTMF và ánh xạ phím -> chỉ số hàng/cột.
%   T = DTMF_TABLE() trả về struct T mô tả bàn phím DTMF 4×3 theo
%   khuyến nghị ITU-T Q.23.
%
%   Đầu ra:
%       T.rowHz - 1×4 double, tần số nhóm thấp (hàng) [Hz]:
%                 [697 770 852 941].
%       T.colHz - 1×3 double, tần số nhóm cao (cột) [Hz]:
%                 [1209 1336 1477].
%       T.keys  - 4×3 char, ký tự của 12 phím, sắp theo (hàng, cột).
%       T.map   - containers.Map; khóa: ký tự phím (char),
%                 giá trị: [rowIdx colIdx] (1×2 double).
%
%   Bố trí bàn phím (hàng: nhóm thấp, cột: nhóm cao; đơn vị Hz):
%
%                1209  1336  1477
%         697      1     2     3
%         770      4     5     6
%         852      7     8     9
%         941      *     0     #
%
%   Ghi chú:
%       - Phím có ký tự key ứng với cặp tần số (T.rowHz(r), T.colHz(c)),
%         trong đó [r, c] = T.map(key).
%       - Cột thứ tư (1633 Hz, các phím A–D) không dùng trong dự án.
%       - Thứ tự bảng này là chuẩn chung, khớp mục "Hợp đồng hàm" trong
%         kế hoạch và CONTRACTS.md; không tự ý thay đổi.
%
%   Ví dụ:
%       T = dtmf_table();
%       T.rowHz(1)     % 697
%       T.map('5')     % [2 2]  -> 770 Hz + 1336 Hz
%
%   Tham khảo:
%       [1] ITU-T Rec. Q.23, "Technical features of push-button
%           telephone sets", 1988.
%       [2] Gói đặc tả #1 (tổ S1).
%
%   See also dtmf_generate, dtmf_decide, dtmf_metrics.

T = struct();
T.rowHz = [697 770 852 941];            % Nhóm tần số thấp (hàng) [Hz]
T.colHz = [1209 1336 1477];             % Nhóm tần số cao (cột) [Hz]
T.keys  = ['123'; '456'; '789'; '*0#'];

% Ánh xạ ký tự phím -> [chỉ số hàng, chỉ số cột].
T.map = containers.Map('KeyType', 'char', 'ValueType', 'any');
for r = 1:4
    for c = 1:3
        T.map(T.keys(r, c)) = [r c];
    end
end

end
