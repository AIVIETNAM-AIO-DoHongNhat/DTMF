function tests = test_metrics
%TEST_METRICS Unit test cho dtmf_metrics - chấm điểm chuỗi phím giải mã được.
tests = functiontests(localfunctions);
end

% ---------------------------------------------------------------- ba trường cơ bản

function test_identicalStrings(testCase)
% Chuỗi giống hệt là ca mốc: mọi trường phải đồng thời "hoàn hảo". Chỉ kiểm acc
% thì một cài đặt trả confusion rỗng vẫn qua được.
m = dtmf_metrics('0912345', '0912345');
testCase.verifyEqual(m.acc, 1);
testCase.verifyEqual(m.editDist, 0);
testCase.verifyEqual(trace(m.confusion), 7);
testCase.verifyEqual(sum(m.confusion(:)), 7);
end

function test_studyExample(testCase)
% Ví dụ trong study (DTMF_LyThuyet.m §12): '123' -> '1283' đúng một phép chèn.
% Giữ nguyên ví dụ này để báo cáo và mã nguồn không lệch nhau.
m = dtmf_metrics('123', '1283');
testCase.verifyEqual(m.editDist, 1);
testCase.verifyEqual(m.acc, 0.75, 'AbsTol', 1e-12);
end

function test_deletionCostsOne(testCase)
% Chiều ngược lại của ca trên. Bỏ số hạng "xóa" trong min([...]) vẫn làm ca
% test_studyExample xanh, vì ca đó chỉ đi qua nhánh chèn.
m = dtmf_metrics('1283', '123');
testCase.verifyEqual(m.editDist, 1);
testCase.verifyEqual(m.acc, 0.75, 'AbsTol', 1e-12);
end

function test_emptyHat(testCase)
% Bộ giải mã không nhận được gì - chuyện thường gặp dưới 6 dB. acc phải là 0
% chứ không phải NaN, và editDist đúng bằng số phím đã mất.
m = dtmf_metrics('0912345', blanks(0));
testCase.verifyEqual(m.acc, 0);
testCase.verifyEqual(m.editDist, 7);

% Xóa không có ô nào trong ma trận 12×12 để ghi - quyết định (g).
testCase.verifyEqual(sum(m.confusion(:)), 0);
end

function test_bothEmpty(testCase)
% 0/0. Quy ước acc = 1: không có phím nào sai thì không có gì để trừ điểm.
% Không chặn ca này thì acc ra NaN và cả cột bảng kết quả ở Buổi 10 thành NaN.
m = dtmf_metrics(blanks(0), blanks(0));
testCase.verifyEqual(m.acc, 1);
testCase.verifyEqual(m.editDist, 0);
testCase.verifyEqual(m.confusion, zeros(12, 12));
end

function test_accUsesMaxOfBothLengths(testCase)
% GHIM mẫu số max(K,L). Lấy numel(keysTrue) thì chuỗi thừa phím vẫn được
% acc = 1, đúng loại lỗi mà nhánh ngân hàng bộ lọc mắc ở Buổi 6 (dư âm bộ lọc
% sinh phím thừa) - công thức chấm điểm không được mù trước chính nó.
m = dtmf_metrics('123', '1123');
testCase.verifyEqual(m.editDist, 1);
testCase.verifyEqual(m.acc, 0.75, 'AbsTol', 1e-12);
end

% ---------------------------------------------------------------- ma trận nhầm lẫn

function test_confusionShape(testCase)
% Hợp đồng ghi 12×12 double, kể cả khi không có cặp nào được căn chỉnh.
m = dtmf_metrics('5', '6');
testCase.verifySize(m.confusion, [12 12]);
testCase.verifyClass(m.confusion, 'double');
end

function test_substitutionLandsInRightCell(testCase)
% Một phép thay '5' -> '6' rơi vào đúng MỘT ô. Trong '147*2580369#' thì '5'
% đứng thứ 6 và '6' đứng thứ 10.
m = dtmf_metrics('5', '6');
expected = zeros(12, 12);
expected(6, 10) = 1;
testCase.verifyEqual(m.confusion, expected);
end

function test_keyOrderIsColumnMajor(testCase)
% GHIM thứ tự phím '147*2580369#' (duyệt T.keys theo CỘT) cho cả hàng lẫn cột.
%
% Đây là bẫy nguy hiểm nhất của hàm này: duyệt theo HÀNG cho ra ma trận CHUYỂN
% VỊ, mà hình vẽ trong báo cáo vẫn trông hoàn toàn hợp lý - đường chéo vẫn là
% đường chéo. Ca dtmf_metrics(k, k) không bắt được lỗi này vì kết quả là eye(12)
% với mọi thứ tự nhất quán; phải dùng cặp KHÔNG đối xứng.
ord = '147*2580369#';
for k = 1:12
    % Gán ra biến rồi mới lấy trường: MATLAB không cho đánh chỉ số thẳng vào
    % kết quả của một lời gọi hàm.
    mRow = dtmf_metrics(ord(k), '1');
    eRow = zeros(12, 12);
    eRow(k, 1) = 1;
    testCase.verifyEqual(mRow.confusion, eRow, ...
        sprintf('Hàng của phím ''%s'' sai vị trí.', ord(k)));

    mCol = dtmf_metrics('1', ord(k));
    eCol = zeros(12, 12);
    eCol(1, k) = 1;
    testCase.verifyEqual(mCol.confusion, eCol, ...
        sprintf('Cột của phím ''%s'' sai vị trí.', ord(k)));
end
end

% ---------------------------------------------------------------- quyết định (g)

function test_accIsDerivedFromEditDist(testCase)
% GHIM acc = 1 - editDist/max(K,L) trên 200 cặp chuỗi ngẫu nhiên.
%
% Công thức thay thế "đếm số ô khớp lúc truy vết / max(K,L)" cho số khác - đo
% được 978/14641 cặp lệch nhau khi vét cạn độ dài 0..4 - và số đó còn phụ thuộc
% thứ tự ưu tiên lúc truy vết. Xem CONTRACTS §6(g).
rng(11);
ord = '147*2580369#';
for r = 1:200
    a = ord(randi(12, 1, randi([0 8])));
    b = ord(randi(12, 1, randi([0 8])));
    m = dtmf_metrics(a, b);
    nKey = max(numel(a), numel(b));
    if nKey == 0
        testCase.verifyEqual(m.acc, 1);
    else
        testCase.verifyEqual(m.acc, 1 - m.editDist/nKey, 'AbsTol', 1e-12, ...
            sprintf('Lệch ở cặp ''%s'' / ''%s''.', a, b));
    end
    testCase.verifyGreaterThanOrEqual(m.acc, 0);
    testCase.verifyLessThanOrEqual(m.acc, 1);
end
end

function test_traceCanExceedAccuracy(testCase)
% GHIM thứ tự ưu tiên truy vết CHÉO > XÓA > CHÈN, và ghim luôn hệ quả của
% quyết định (g): trace(confusion) có thể LỚN HƠN acc*max(K,L).
%
% Tính tay cho '121' -> '212': editDist = 2, và đường ưu tiên chéo là
% chèn '2' · khớp '1' · khớp '2' · xóa '1'. Vậy trace = 2 trong khi
% acc*max = (1 - 2/3)*3 = 1. Cặp chèn+xóa thay cho một phép thay giữ nguyên
% chi phí nhưng tăng số ô khớp - đó chính là lý do acc không đếm ô khớp.
m = dtmf_metrics('121', '212');
testCase.verifyEqual(m.editDist, 2);
testCase.verifyEqual(m.acc, 1/3, 'AbsTol', 1e-12);

expected = zeros(12, 12);
expected(1, 1) = 1;     % '1' khớp '1'
expected(5, 5) = 1;     % '2' khớp '2'
testCase.verifyEqual(m.confusion, expected);
testCase.verifyEqual(trace(m.confusion), 2);
end

% ---------------------------------------------------------------- lỗi và đầu-cuối

function test_tieBreakIsPinned(testCase)
% GHIM thứ tự ưu tiên truy vết bằng cặp chuỗi NGẮN NHẤT phân biệt được nó.
%
% '12' -> '3' có editDist = 2 theo hai đường CÙNG tối ưu: xóa '1' rồi thay
% '2'->'3', hoặc xóa '2' rồi thay '1'->'3'. Hai đường cho cùng acc nhưng ghi
% vào hai ô KHÁC NHAU của ma trận nhầm lẫn. Không đường nào "đúng" hơn - nên
% luật phải được ghim, nếu không mỗi lần sửa vòng truy vết là hình vẽ trong báo
% cáo đổi mà không ca nào đỏ.
%
% Lỗ hổng này do kiểm thử đột biến tìm ra: ca test_traceCanExceedAccuracy không
% bắt được, vì đường đi của '121'/'212' bắt đầu bằng một phép xóa ở cả hai luật.
m = dtmf_metrics('12', '3');
testCase.verifyEqual(m.editDist, 2);

expected = zeros(12, 12);
expected(5, 9) = 1;     % ưu tiên CHÉO: '2' -> '3', rồi mới xóa '1'
testCase.verifyEqual(m.confusion, expected, ...
    'Truy vet khong con uu tien CHEO: cap 12/3 da roi sang o khac.');
end

function test_badKeyErrors(testCase)
% Ký tự ngoài 12 phím là gọi sai hàm, không phải dữ liệu xấu cần bỏ qua: nuốt
% im lặng sẽ cho một acc trông bình thường nhưng vô nghĩa. Kiểm cả hai tham số.
testCase.verifyError(@() dtmf_metrics('12X', '123'), 'dtmf_metrics:badKey');
testCase.verifyError(@() dtmf_metrics('123', '12A'), 'dtmf_metrics:badKey');
testCase.verifyError(@() dtmf_metrics('1 2', '123'), 'dtmf_metrics:badKey');
end

function test_allThreeDecodersScorePerfect(testCase)
% Tiêu chí nghiệm thu của Buổi 7: trên tín hiệu sạch cả ba bộ giải mã phải đạt
% acc = 1. Ca này nối dtmf_metrics với phần còn lại của dự án - nếu ai đó đổi
% quy ước chuỗi rỗng hay thứ tự phím, nó đỏ ngay.
[x, ~, meta] = dtmf_generate('0912345*#');
f = {@dtmf_decode_goertzel, @dtmf_decode_fft, @dtmf_decode_filterbank};
for k = 1:3
    m = dtmf_metrics(meta.keys, f{k}(x));
    testCase.verifyEqual(m.acc, 1, sprintf('Bộ giải mã thứ %d không đạt.', k));
    testCase.verifyEqual(m.editDist, 0);
    testCase.verifyEqual(trace(m.confusion), numel(meta.keys));
end
end
