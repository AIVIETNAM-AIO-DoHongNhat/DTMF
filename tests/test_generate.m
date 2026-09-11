function tests = test_generate
%TEST_GENERATE Unit test cơ bản cho dtmf_generate và dtmf_addnoise.
%
%   See also dtmf_generate, dtmf_addnoise, run_all_tests.
tests = functiontests(localfunctions);
end

function test_outputShapeAndRange(testCase)
% Kiểm tra: x và t cùng số mẫu, |x| <= 1, meta.keys giữ nguyên chuỗi vào.
[x, t, meta] = dtmf_generate('5', 'fs', 8000, 'toneMs', 100, 'pauseMs', 50);
testCase.verifyEqual(numel(x), numel(t));
testCase.verifyLessThanOrEqual(max(abs(x)), 1.0);
testCase.verifyEqual(meta.keys, '5');
end

function test_addnoiseSnr(testCase)
% Kiểm tra: SNR đo được khớp SNR mục tiêu với sai số ±0.5 dB,
% SNR_đo = 10*log10(sum(x.^2) / sum((y - x).^2)).
[x, ~, ~] = dtmf_generate('1', 'fs', 8000);
targetSnr = 10;
y = dtmf_addnoise(x, 'snrDb', targetSnr, 'type', 'awgn');
measuredSnr = 10 * log10(sum(x.^2) / sum((y - x).^2));
testCase.verifyEqual(measuredSnr, targetSnr, 'AbsTol', 0.5);
end
