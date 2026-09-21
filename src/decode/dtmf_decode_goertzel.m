function [keys, info] = dtmf_decode_goertzel(y, opt)
%DTMF_DECODE_GOERTZEL Giải mã DTMF bằng thuật toán Goertzel
% Nghe lại đoạn âm thanh rồi đọc ra dãy phím đã bấm
%   [KEYS, INFO] = DTMF_DECODE_GOERTZEL(Y) giải mã Y với tham số mặc định.
%   Ba bộ giải mã dùng chung chữ ký này (xem CONTRACTS.md).
%
%   Các bước hoạt động:
%       1. dtmf_segment chia Y thành khung.
%       2. goertzel_power đo công suất 7 bin chuẩn + 1 bin hài mỗi khung, rồi
%          chia cho năng lượng khung để sum(E(1:7)) thành TỈ LỆ năng lượng.
%       3. dtmf_decide phán quyết từng khung: phím nào, hay loại vì lý do gì.
%       4. Các khung liên tiếp cùng phím gộp thành MỘT ký tự; khung bị loại
%          cắt dải, nhờ vậy '99' ra hai ký tự chứ không phải một.
%
%   Input:
%       y: 1×N double, tín hiệu cần giải mã.
%
%   Tham số tên–giá trị (mặc định trong ngoặc):
%       'fs': tần số lấy mẫu [Hz] (8000).
%       'frameN': độ dài khung [mẫu] (205); Δf = fs/frameN ≈ 39.02 Hz.
%       'hop': bước nhảy giữa hai khung [mẫu] (205).
%
%   Output:
%       keys: char 1×K, dãy phím đọc được; 1×0 nếu không nhận được khung nào.
%       info: số liệu theo khung, mọi trường dài nFrame - .E 8×nFrame (đã
%             chuẩn hóa), .rowIdx .colIdx .conf .tFrame 1×nFrame, .reject cell
%             1×nFrame. .tFrame là TÂM khung [s].
%
%   Example:
%       dtmf_decode_goertzel(dtmf_generate('0912345'))   % '0912345'
arguments
    y (1,:) double
    opt.fs (1,1) double = 8000
    opt.frameN (1,1) double = 205
    opt.hop (1,1) double = 205
end

T = dtmf_table();
k = round(opt.frameN * [T.rowHz T.colHz] / opt.fs);

seg = dtmf_segment(y, 'fs', opt.fs, 'frameN', opt.frameN, 'hop', opt.hop);
n   = numel(seg);

% Cấp phát đúng cỡ hợp đồng. n = 0 rơi luôn vào đây: zeros(8,0) là 8×0 và
% cell(1,0) là 1×0, không cần nhánh if riêng. Phải bọc {cell(1,n)} vì struct()
% coi cell là danh sách giá trị, không bọc sẽ ra mảng struct 1×n.
info = struct('E',      zeros(8, n), ...
              'rowIdx', zeros(1, n), ...
              'colIdx', zeros(1, n), ...
              'conf',   zeros(1, n), ...
              'tFrame', zeros(1, n), ...
              'reject', {cell(1, n)});

for i = 1:n
    frame = y(seg(i).idx(1):seg(i).idx(2));

    P = zeros(8, 1);
    for j = 1:7
        P(j) = goertzel_power(frame, k(j), opt.frameN);
    end

    % Bin hài bám theo đỉnh của CHÍNH khung này - quyết định (b). floor(N/2)
    % thực tế không bao giờ cắt (xấu nhất 2*38 = 76 <= 102), chỉ là chốt chặn.
    [~, d] = max(P(1:7));
    P(8) = goertzel_power(frame, min(2*k(d), floor(opt.frameN/2)), opt.frameN);

    % Chuẩn hóa theo quyết định (a). Khung im lặng có en = 0: để nguyên E = 0,
    % dtmf_decide trả 'level'. Chia thẳng sẽ cho 0/0 = NaN, mà mọi so sánh với
    % NaN đều false nên khung rác lọt qua với nhãn 'none'.
    en = opt.frameN * sum(frame.^2) / 2;
    if en > 0
        info.E(:, i) = P / en;
    end

    [info.rowIdx(i), info.colIdx(i), info.conf(i), info.reject{i}] = ...
        dtmf_decide(info.E(:, i));

    info.tFrame(i) = (seg(i).tStart + seg(i).tEnd) / 2;   % TÂM khung, (e)
end

% Debounce: mỗi DẢI khung liên tiếp cùng một phím sinh đúng MỘT ký tự. So sánh
% bằng chỉ số phím 1..12; khung bị loại cho 0 và cắt dải, nhờ đó hai lần bấm
% cùng một phím vẫn ra hai ký tự.
keys = blanks(n);       % nhiều nhất n ký tự; cắt lại đúng cỡ sau vòng lặp
nKey = 0;
prev = 0;

for i = 1:n
    if info.rowIdx(i) == 0
        prev = 0;
        continue
    end

    cur = (info.rowIdx(i) - 1) * 3 + info.colIdx(i);
    if cur ~= prev
        nKey = nKey + 1;
        keys(nKey) = T.keys(info.rowIdx(i), info.colIdx(i));
    end
    prev = cur;
end

keys = keys(1:nKey);

end
