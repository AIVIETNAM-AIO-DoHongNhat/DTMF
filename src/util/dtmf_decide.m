function [rowIdx, colIdx, conf, reject] = dtmf_decide(E, opt)
%DTMF_DECIDE Luật quyết định chung: 8 công suất của một khung -> phím bấm
% Nhìn 8 con số đo được của một khung rồi trả lời: đây là phím nào, hay là rác
%   [ROWIDX, COLIDX, CONF, REJECT] = DTMF_DECIDE(E) áp dụng luật quyết định
%   cho MỘT khung với các ngưỡng mặc định.
%
%   [...] = DTMF_DECIDE(E, Name, Value) đổi ngưỡng qua các cặp tên–giá trị.
%
%   E là CÔNG SUẤT nên mọi tỉ số tính bằng 10*log10(...). Năm điều kiện xét
%   theo đúng thứ tự, trượt cái nào thì dừng ngay ở cái đó và lấy nhãn của nó.
%
%   Các bước hoạt động:
%       1. 10*log10(rowPeak/rowPeak2) >= peakDb              -> 'level'
%       2. 10*log10(colPeak/colPeak2) >= peakDb              -> 'level'
%       3. 10*log10(colPeak/rowPeak) trong [-twistBwdDb, twistFwdDb] -> 'twist'
%       4. sum(E(1:7)) >= energyRatio                        -> 'level'
%       5. E(8) <= 0.5*min(rowPeak, colPeak)                 -> 'harmonic'
%       6. Qua hết: reject = 'none', rowIdx/colIdx là vị trí hai đỉnh, và
%          conf = min(1, sum(E(1:7))) * min(1, min(dRow, dCol)/(2*peakDb)).
%   Điều kiện 4 đòi E ĐÃ CHUẨN HÓA theo năng lượng khung (CONTRACTS.md, quyết
%   định (a)); đó cũng là điều kiện duy nhất phụ thuộc thang đo, bốn cái còn
%   lại đều là tỉ số nên nhân E với hằng số bất kỳ vẫn cho cùng một phím.
%
%   Input:
%       E: 8×1 double >= 0, công suất của MỘT khung tại [697 770 852 941 1209
%          1336 1477] Hz và bin hài bậc 2; E(1:4) nhóm hàng, E(5:7) nhóm cột,
%          E(8) hài. Gọi nhiều khung thì lặp và truyền E(:,i).
%
%   Tham số tên–giá trị (mặc định trong ngoặc):
%       'peakDb': đỉnh phải nổi hơn đỉnh nhì CÙNG NHÓM ít nhất chừng này [dB] (6).
%       'energyRatio': tỉ lệ năng lượng tối thiểu của 7 bin chuẩn (0.70).
%       'twistFwdDb': twist thuận tối đa, cột mạnh hơn hàng [dB] (4).
%       'twistBwdDb': twist nghịch tối đa, hàng mạnh hơn cột [dB] (8).
%
%   Output:
%       rowIdx: 1..4, chỉ số hàng; 0 nếu khung bị loại.
%       colIdx: 1..3, chỉ số cột; 0 nếu khung bị loại.
%       conf: double trong [0, 1], độ tin cậy; 0 khi khung bị loại.
%       reject: char, lý do loại - 'none' | 'level' | 'twist' | 'harmonic'.
%
%   Example:
%       E = [1 8 1 1  1 9 1  0.1]';
%       [r, c, conf, rej] = dtmf_decide(E)   % r = 2, c = 2, rej = 'none'
arguments
    E (8,:) double
    opt.peakDb (1,1) double = 6
    opt.energyRatio (1,1) double = 0.70
    opt.twistFwdDb (1,1) double = 4
    opt.twistBwdDb (1,1) double = 8
end

% Bốn đầu ra là vô hướng. Khối arguments khai E (8,:) nên 8×n vẫn lọt qua, rồi
% max() vector hóa làm cả bốn đầu ra thành vector - sai mà không ai báo.
if size(E, 2) ~= 1
    error('dtmf_decide:notOneFrame', ...
        'E có %d cột; mỗi lần gọi chỉ truyền MỘT khung E(:,i).', size(E, 2));
end

rowIdx = 0;                     % giá trị dùng chung cho mọi nhánh bị loại
colIdx = 0;
conf   = 0;

% Chốt chặn trước mọi log10. E âm cho tỉ số âm -> log10 ra SỐ PHỨC, mà MATLAB
% so sánh số phức bằng phần thực nên năm điều kiện sai im lặng. Khung toàn 0
% cho NaN, cũng vậy.
if ~all(isfinite(E)) || any(E < 0) || max(E) <= 0
    reject = 'level';
    return
end

[rowPeak, rowArg] = max(E(1:4));
[colPeak, colArg] = max(E(5:7));

% Đỉnh nhì phải lấy CÙNG NHÓM, không phải nhóm kia.
rowSorted = sort(E(1:4), 'descend');
colSorted = sort(E(5:7), 'descend');

dRow  = 10*log10(rowPeak / rowSorted(2));
dCol  = 10*log10(colPeak / colSorted(2));
twist = 10*log10(colPeak / rowPeak);
rho   = sum(E(1:7));

% Viết ở dạng KHẲNG ĐỊNH rồi phủ định cả cụm. Nhóm hàng toàn 0 cho dRow = NaN,
% mà 'NaN < peakDb' là false: viết 'if dRow < opt.peakDb' sẽ cho khung rác lọt
% qua và gắn nhãn 'none' - đúng cái bẫy Study §10.1 mô tả.
if ~(dRow >= opt.peakDb && dCol >= opt.peakDb)
    reject = 'level';
    return
end

if ~(twist >= -opt.twistBwdDb && twist <= opt.twistFwdDb)
    reject = 'twist';
    return
end

if ~(rho >= opt.energyRatio)
    reject = 'level';
    return
end

if ~(E(8) <= 0.5*min(rowPeak, colPeak))
    reject = 'harmonic';
    return
end

% min(1, rho): hàm không kiểm được caller đã chuẩn hóa E chưa, thiếu cái kẹp
% này thì E thô cho conf hàng chục. E chuẩn hóa đúng có rho <= 1 nên vô hại.
rowIdx = rowArg;
colIdx = colArg;
conf   = min(1, rho) * min(1, min(dRow, dCol) / (2*opt.peakDb));
reject = 'none';

end
