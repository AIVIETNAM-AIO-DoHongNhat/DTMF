function T = dtmf_table()
%DTMF_TABLE Bảng tần số chuẩn DTMF và ánh xạ phím -> chỉ số hàng/cột
% Tra xem mỗi phím trên bàn phím điện thoại ứng với cặp tần số nào
%   T = DTMF_TABLE() trả về struct T mô tả bàn phím DTMF 4×3 theo khuyến
%   nghị ITU-T Q.23.
%
%   Mỗi phím nằm ở giao của một tần số hàng (nhóm thấp) và một tần số cột
%   (nhóm cao); phím key ứng với cặp (T.rowHz(r), T.colHz(c)) trong đó
%   [r, c] = T.map(key). Đơn vị trong sơ đồ là Hz:
%
%                1209  1336  1477
%         697      1     2     3
%         770      4     5     6
%         852      7     8     9
%         941      *     0     #
%
%   Cột thứ tư (1633 Hz, các phím A–D) không dùng trong dự án. Thứ tự bảng
%   này là chuẩn chung, khớp mục "Hợp đồng hàm" trong CONTRACTS.md - không
%   tự ý thay đổi.
%
%   Output:
%       T.rowHz: 1×4 double, tần số nhóm thấp (hàng) [Hz]: [697 770 852 941].
%       T.colHz: 1×3 double, tần số nhóm cao (cột) [Hz]: [1209 1336 1477].
%       T.keys: 4×3 char, ký tự của 12 phím, sắp theo (hàng, cột).
%       T.map: containers.Map; khóa là ký tự phím (char), giá trị là
%              [rowIdx colIdx] (1×2 double).
%
%   Example:
%       T = dtmf_table();
%       T.rowHz(1)     % 697
%       T.map('5')     % [2 2] -> 770 Hz + 1336 Hz
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
