function keys = dtmf_debounce(rowIdx, colIdx, opt)
%DTMF_DEBOUNCE Gộp phán quyết từng khung thành chuỗi phím
% Bốn khung liên tiếp cùng thấy phím '5' là MỘT lần bấm, không phải bốn
%   KEYS = DTMF_DEBOUNCE(ROWIDX, COLIDX) gộp theo luật mặc định.
%   Cả ba bộ giải mã gọi hàm này, không bộ nào tự gộp lấy - xem CONTRACTS §6(f).
%
%   Các bước hoạt động:
%       1. Khung bị loại có rowIdx = 0. Nó CẮT dải, nhờ vậy hai lần bấm cùng
%          một phím vẫn ra hai ký tự chứ không dính thành một.
%       2. Các khung liên tiếp cùng chỉ số phím (rowIdx-1)*3+colIdx gộp thành
%          một DẢI.
%       3. Dải dài >= minRun khung mới sinh ký tự. Một phím kéo 100 ms = 3.9
%          khung ở frameN = 205, nên dải dài đúng MỘT khung không phải phím
%          thật - đo được: dải ngắn nhất của phím thật là 3 khung ở mọi mức
%          tới 8 dB (CONTRACTS §7.5).
%
%   Input:
%       rowIdx: 1×nFrame double, chỉ số hàng 1..4 mỗi khung, 0 nếu khung bị loại.
%       colIdx: 1×nFrame double, chỉ số cột 1..3 mỗi khung, 0 nếu khung bị loại.
%
%   Tham số tên–giá trị (mặc định trong ngoặc):
%       'minRun': số khung tối thiểu của một dải để sinh ký tự (2).
%
%   Output:
%       keys: char 1×K, dãy phím theo thứ tự thời gian; 1×0 nếu không dải nào
%             đủ dài.
%
%   Example:
%       dtmf_debounce([2 2 2 0 2 2 2], [2 2 2 0 2 2 2])   % '55'
arguments
    rowIdx (1,:) double
    colIdx (1,:) double
    opt.minRun (1,1) double = 2
end

if numel(rowIdx) ~= numel(colIdx)
    error('dtmf_debounce:sizeMismatch', ...
        'rowIdx có %d phần tử còn colIdx có %d; hai vector phải dài bằng nhau.', ...
        numel(rowIdx), numel(colIdx));
end

% Một khung hoặc được nhận (cả hai chỉ số khác 0) hoặc bị loại (cả hai bằng 0).
% Lệch nhau nghĩa là bộ giải mã điền info sai; không chặn thì rowIdx = 0 kèm
% colIdx = 2 bị coi là khung bị loại và cái sai biến mất không dấu vết.
if any((rowIdx == 0) ~= (colIdx == 0))
    error('dtmf_debounce:mismatchedIdx', ...
        'rowIdx và colIdx phải cùng bằng 0 hoặc cùng khác 0 trên mỗi khung.');
end

T = dtmf_table();
n = numel(rowIdx);

keys = blanks(n);       % nhiều nhất n ký tự; cắt lại đúng cỡ sau vòng lặp
nKey = 0;
i    = 1;

while i <= n
    if rowIdx(i) == 0
        i = i + 1;
        continue
    end

    % Chạy hết dải khung liên tiếp cùng một phím, so sánh bằng chỉ số 1..12.
    % 'rowIdx(j+1) > 0' nhìn thì thừa - khung bị loại cho (0-1)*3+0 = -3, không
    % bao giờ bằng cur - nhưng giữ lại vì nó nêu Ý ĐỊNH "khung bị loại cắt dải"
    % ngay tại chỗ, thay vì phó mặc cho việc -3 tình cờ nằm ngoài 1..12.
    cur = (rowIdx(i) - 1) * 3 + colIdx(i);
    j   = i;
    while j < n && rowIdx(j+1) > 0 && (rowIdx(j+1) - 1) * 3 + colIdx(j+1) == cur
        j = j + 1;
    end

    if j - i + 1 >= opt.minRun
        nKey = nKey + 1;
        keys(nKey) = T.keys(rowIdx(i), colIdx(i));
    end

    i = j + 1;
end

keys = keys(1:nKey);

end
