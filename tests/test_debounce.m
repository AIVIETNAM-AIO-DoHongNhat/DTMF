function tests = test_debounce
%TEST_DEBOUNCE Unit test cho dtmf_debounce - luật gộp dùng chung cho 3 bộ giải mã.
tests = functiontests(localfunctions);
end

function test_mergesRun(testCase)
% Bốn khung liên tiếp cùng phím là MỘT lần bấm. Đây là lý do hàm này tồn tại:
% tone 100 ms trải ra ~3.9 khung, không gộp thì mỗi phím ra bốn ký tự.
testCase.verifyEqual(dtmf_debounce([2 2 2 2], [2 2 2 2]), '5');
end

function test_rejectedFrameSplitsRun(testCase)
% Khung bị loại (rowIdx = 0) CẮT dải. Đây là thứ duy nhất tách được hai lần
% bấm cùng một phím; bỏ nó đi thì '99' thành '9' mà không có dấu hiệu gì.
testCase.verifyEqual(dtmf_debounce([3 3 0 3 3], [3 3 0 3 3]), '99');
testCase.verifyEqual(dtmf_debounce([3 3 3 3 3], [3 3 3 3 3]), '9');
end

function test_dropsSingleFrameRun(testCase)
% GHIM minRun = 2. Dải dài đúng một khung bị bỏ.
%
% Với minRun = 1 thì nhánh ngân hàng bộ lọc chèn thêm ký tự: dư âm bộ lọc làm
% một khung trong khoảng lặng vẫn được nhận, rồi quá độ ở đầu tone kế tiếp
% loại khung ngay sau đó, để lại đúng một dải cô lập dài một khung. Đo được
% 29/42 cách căn lề bị hỏng - xem CONTRACTS §7.5.
testCase.verifyEqual(dtmf_debounce([2 0 2 2], [2 0 2 2]), '5');
testCase.verifyEmpty(dtmf_debounce(2, 2));
testCase.verifyEmpty(dtmf_debounce([2 0 3 0 4], [2 0 3 0 1]));
end

function test_minRunIsTunable(testCase)
% minRun phơi ra ngoài để run_bench ở Buổi 10 quét được, và để ca trên chứng
% minh được là luật chứ không phải hằng số ngẫu nhiên.
r = [2 0 2 2 0 2 2 2];
c = [2 0 2 2 0 2 2 2];
testCase.verifyEqual(dtmf_debounce(r, c, 'minRun', 1), '555');
testCase.verifyEqual(dtmf_debounce(r, c, 'minRun', 2), '55');
testCase.verifyEqual(dtmf_debounce(r, c, 'minRun', 3), '5');
testCase.verifyEqual(dtmf_debounce(r, c, 'minRun', 4), blanks(0));
end

function test_allTwelveKeys(testCase)
% Ánh xạ (rowIdx, colIdx) -> ký tự phải khớp dtmf_table theo đúng thứ tự đọc.
% Sai công thức (rowIdx-1)*3+colIdx thì vài phím đổi chỗ cho nhau mà chuỗi vẫn
% dài đúng bằng ấy ký tự.
T = dtmf_table();
r = zeros(1, 36);       % mỗi phím hai khung liên tiếp, rồi một khung bị loại
c = zeros(1, 36);
p = 0;
for i = 1:4
    for j = 1:3
        r(p+1:p+2) = i;
        c(p+1:p+2) = j;
        p = p + 3;      % phần tử thứ ba giữ nguyên 0 để cắt dải
    end
end
testCase.verifyEqual(dtmf_debounce(r, c), reshape(T.keys', 1, []));
end

function test_emptyInput(testCase)
% nFrame = 0: phải trả 1×0 char, KHÔNG phải '' (0×0) và không ném lỗi.
keys = testCase.verifyWarningFree(@() dtmf_debounce(zeros(1,0), zeros(1,0)));
testCase.verifyEmpty(keys);
testCase.verifyClass(keys, 'char');
testCase.verifyEqual(size(keys), [1 0]);
end

function test_allRejected(testCase)
% Mọi khung bị loại: không ký tự nào.
testCase.verifyEmpty(dtmf_debounce(zeros(1,10), zeros(1,10)));
end

function test_rejectsInconsistentIdx(testCase)
% rowIdx = 0 kèm colIdx ~= 0 nghĩa là bộ giải mã điền info sai. Không chặn thì
% khung đó bị coi là bị loại và cái sai biến mất không dấu vết.
testCase.verifyError(@() dtmf_debounce([0 2], [2 2]), 'dtmf_debounce:mismatchedIdx');
testCase.verifyError(@() dtmf_debounce([2 2], [0 2]), 'dtmf_debounce:mismatchedIdx');
testCase.verifyError(@() dtmf_debounce([2 2 2], [2 2]), 'dtmf_debounce:sizeMismatch');
end

function test_decodersDelegateHere(testCase)
% Ba bộ giải mã PHẢI gọi hàm này chứ không tự gộp. Ca này dựng lại keys từ
% info.rowIdx/info.colIdx và đòi trùng khít đầu ra của bộ giải mã - ai chép
% vòng gộp vào lại bộ giải mã rồi sửa một bên là đỏ ngay.
x = dtmf_generate('12345699');
for f = {@dtmf_decode_goertzel, @dtmf_decode_fft}
    [keys, info] = f{1}(x);
    testCase.verifyEqual(keys, dtmf_debounce(info.rowIdx, info.colIdx), ...
        func2str(f{1}));
    testCase.verifyEqual(keys, '12345699', func2str(f{1}));
end
end
