function m = dtmf_metrics(keysTrue, keysHat)
%DTMF_METRICS Đo độ chính xác của chuỗi phím giải mã được
% Chấm bài bộ giải mã: đúng được bao nhiêu, sai mấy chỗ, hay nhầm phím nào với phím nào
%   M = DTMF_METRICS(KEYSTRUE, KEYSHAT) so sánh chuỗi giải mã KEYSHAT với nhãn
%   gốc KEYSTRUE. Hai chuỗi KHÔNG cần dài bằng nhau: bộ giải mã có thể bỏ sót
%   hoặc chèn thêm phím, nên phải căn chỉnh hai chuỗi trước khi so từng vị trí.
%
%   Các bước hoạt động:
%       1. Đổi mỗi ký tự thành chỉ số 1..12 theo thứ tự duyệt CỘT của
%          dtmf_table().keys, tức '147*2580369#'. Ký tự ngoài 12 phím DTMF là
%          lỗi gọi hàm, không phải dữ liệu xấu cần bỏ qua.
%       2. Dựng bảng quy hoạch động D của khoảng cách Levenshtein:
%          D(i,j) = min(D(i-1,j)+1, D(i,j-1)+1, D(i-1,j-1) + (A(i)~=B(j))) -
%          ba số hạng lần lượt là xóa, chèn, thay. editDist = D(end,end).
%       3. Truy vết ngược D để căn chỉnh hai chuỗi, ưu tiên CHÉO > XÓA > CHÈN.
%          Mỗi bước chéo là một cặp (phím thật, phím đoán), cộng 1 vào ô tương
%          ứng của confusion. Bước chèn và xóa không có ô nào để ghi.
%       4. acc = 1 - editDist/max(K,L). Hai chuỗi cùng rỗng cho acc = 1.
%
%   acc tính thẳng từ editDist chứ KHÔNG đếm số ô khớp lúc truy vết. Số ô khớp
%   phụ thuộc thứ tự ưu tiên lúc truy vết - đo được chênh tới 2 ký tự trên chuỗi
%   dài 4 - còn cách này thì không. Hệ quả: trace(confusion) có thể lớn hơn
%   acc*max(K,L). Xem CONTRACTS §6(g).
%
%   Input:
%       keysTrue: char 1×K, chuỗi phím đúng (nhãn gốc).
%       keysHat: char 1×L, chuỗi phím bộ giải mã trả về.
%
%   Output:
%       m: struct 1×1 gồm ba trường
%          .acc: double trong [0, 1], tỉ lệ phím đúng.
%          .editDist: double, số phép chèn/xóa/thay ít nhất.
%          .confusion: 12×12 double, ô (i,j) là số lần phím thật i bị giải
%                      thành phím j; đường chéo là số lần đúng.
%
%   Example:
%       m = dtmf_metrics('123', '1283');
%       m.editDist      % 1  (chèn thêm một phím '8')
%       m.acc           % 0.75
arguments
    keysTrue (1,:) char
    keysHat (1,:) char
end

T = dtmf_table();

% Duyệt theo CỘT, không phải theo hàng. Duyệt theo hàng cũng cho một ma trận
% 12×12 trông hợp lý y hệt, nhưng là ma trận CHUYỂN VỊ của ma trận đúng - nhìn
% hình vẽ trong báo cáo thì gần như không thể phát hiện.
iTrue = key_index(keysTrue, T);
iHat  = key_index(keysHat,  T);

K = numel(iTrue);
L = numel(iHat);

% Hàng 0 và cột 0 của bảng là chi phí biến chuỗi rỗng thành một tiền tố, đúng
% bằng độ dài tiền tố đó. Thiếu hai dòng này thì mọi chi phí đều ra 0.
D = zeros(K+1, L+1);
D(:, 1) = (0:K)';
D(1, :) =  0:L;
for i = 1:K
    for j = 1:L
        D(i+1, j+1) = min([D(i,   j+1) + 1, ...                     % xóa
                           D(i+1, j)   + 1, ...                     % chèn
                           D(i,   j) + (iTrue(i) ~= iHat(j))]);     % thay
    end
end
editDist = D(K+1, L+1);

% Truy vết ngược để căn chỉnh. Thứ tự ưu tiên CHÉO > XÓA > CHÈN là một phần của
% hợp đồng - xem CONTRACTS §6(g): khi nhiều đường cùng tối ưu, thứ tự ưu tiên
% khác nhau cho ra ma trận nhầm lẫn khác nhau, nên nó phải được ghim.
C = zeros(12, 12);
i = K + 1;
j = L + 1;
while i > 1 || j > 1
    if i > 1 && j > 1 && D(i, j) == D(i-1, j-1) + (iTrue(i-1) ~= iHat(j-1))
        C(iTrue(i-1), iHat(j-1)) = C(iTrue(i-1), iHat(j-1)) + 1;
        i = i - 1;
        j = j - 1;
    elseif i > 1 && D(i, j) == D(i-1, j) + 1
        i = i - 1;      % xóa: phím thật không được đoán ra, không có ô để ghi
    else
        j = j - 1;      % chèn: phím thừa, cũng không có ô để ghi
    end
end

% Mẫu số là max(K,L) chứ không phải numel(keysTrue). Lấy numel(keysTrue) thì bộ
% giải mã chèn thêm phím vẫn được acc = 1, vì mọi phím thật đều có mặt.
% Hai chuỗi cùng rỗng là 0/0: quy ước acc = 1 vì không có phím nào sai.
nKey = max(K, L);
if nKey == 0
    acc = 1;
else
    acc = 1 - editDist / nKey;
end

m = struct('acc', acc, 'editDist', editDist, 'confusion', C);

end

function idx = key_index(keys, T)
%KEY_INDEX Đổi chuỗi phím thành chỉ số 1..12 theo thứ tự duyệt cột của T.keys.
% sub2ind([4 3], r, c) = r + (c-1)*4, đúng bằng vị trí của phím trong T.keys(:).
idx = zeros(1, numel(keys));
for k = 1:numel(keys)
    if ~isKey(T.map, keys(k))
        error('dtmf_metrics:badKey', ...
            'Ký tự ''%s'' không nằm trong 12 phím DTMF ''%s''.', ...
            keys(k), reshape(T.keys, 1, []));
    end
    rc = T.map(keys(k));
    idx(k) = sub2ind([4 3], rc(1), rc(2));
end
end
