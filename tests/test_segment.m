function tests = test_segment
%TEST_SEGMENT Unit test cho dtmf_segment - chia khung dùng chung cho 3 bộ giải mã.
tests = functiontests(localfunctions);
end

function test_frameCount(testCase)
% Ba bộ tham số chốt trong KE_HOACH.md. Quên -frameN hoặc quên +1 trong
% công thức đều làm lệch đúng 1 khung ở cả ba ca.
testCase.verifyEqual(numel(dtmf_segment(zeros(1, 1000))), 4);
testCase.verifyEqual( ...
    numel(dtmf_segment(zeros(1, 1000), 'frameN', 256, 'hop', 128)), 6);
testCase.verifyEqual(numel(dtmf_segment(zeros(1, 100))), 0);
end

function test_firstFrameIndices(testCase)
% Khung đầu phải là [1 205]: bắt lỗi đánh chỉ số từ 0 thay vì từ 1.
seg = dtmf_segment(zeros(1, 1000));
testCase.verifyEqual(seg(1).idx, [1 205]);
end

function test_noZeroPadding(testCase)
% Khung cuối không được vượt quá numel(y) - tức đuôi thừa bị BỎ chứ không
% đệm 0. Thử vài độ dài lẻ để đuôi thừa khác nhau.
for N = [997 1000 1024]
    seg = dtmf_segment(zeros(1, N));
    testCase.verifyLessThanOrEqual(seg(end).idx(2), N);
end
end

function test_timeStamps(testCase)
% tStart/tEnd phải suy ra từ fs, không hard-code 8000. Trừ 1 ở tStart vì
% chỉ số mẫu đếm từ 1 còn thời gian đếm từ 0.
for fs = [8000 16000]
    seg = dtmf_segment(zeros(1, 1000), 'fs', fs);
    for i = 1:numel(seg)
        testCase.verifyEqual(seg(i).tStart, (seg(i).idx(1) - 1)/fs, 'AbsTol', 1e-12);
        testCase.verifyEqual(seg(i).tEnd,    seg(i).idx(2)/fs,      'AbsTol', 1e-12);
    end
end
end

function test_framesAreContiguous(testCase)
% Quy ước THỜI LƯỢNG (CONTRACTS.md (d)): với hop = frameN, khung sau bắt
% đầu đúng chỗ khung trước kết thúc. Nếu ai đổi tEnd thành (idx(2)-1)/fs
% thì ca này đỏ - đó chính là mục đích của nó.
seg = dtmf_segment(zeros(1, 1000), 'frameN', 205, 'hop', 205);
for i = 1:numel(seg)-1
    testCase.verifyEqual(seg(i).tEnd, seg(i+1).tStart, 'AbsTol', 1e-12);
end
testCase.verifyEqual(seg(1).tEnd - seg(1).tStart, 205/8000, 'AbsTol', 1e-12);
end

function test_hopIndependentOfFrameN(testCase)
% hop KHÔNG tự bằng frameN. Với frameN=256, hop=128 các khung chồng lấp
% nhau một nửa; viết nhầm hop = frameN sẽ cho seg(2).idx = [257 512].
seg = dtmf_segment(zeros(1, 1000), 'frameN', 256, 'hop', 128);
testCase.verifyEqual(seg(2).idx, [129 384]);
firstIdx = arrayfun(@(s) s.idx(1), seg);
testCase.verifyEqual(unique(diff(firstIdx)), 128);
end

function test_emptyWhenTooShort(testCase)
% y ngắn hơn một khung phải trả struct RỖNG 1×0, không ném lỗi: Buổi 8 GUI
% gọi hàm này với tín hiệu bất kỳ, ném lỗi ở đây là sập giao diện.
seg = testCase.verifyWarningFree(@() dtmf_segment(zeros(1, 100)));
testCase.verifyEqual(size(seg), [1 0]);
testCase.verifyTrue(isstruct(seg));
testCase.verifyEqual(sort(fieldnames(seg)), {'idx'; 'tEnd'; 'tStart'});
end
