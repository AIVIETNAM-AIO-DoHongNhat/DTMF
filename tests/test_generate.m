function tests = test_generate
%TEST_GENERATE Unit test cho dtmf_generate và dtmf_addnoise.
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
% SNR đo được phải khớp SNR mục tiêu trong ±0.5 dB.
[x, ~, ~] = dtmf_generate('1', 'fs', 8000);
targetSnr = 10;
y = dtmf_addnoise(x, 'snrDb', targetSnr, 'type', 'awgn');
measuredSnr = 10 * log10(sum(x.^2) / sum((y - x).^2));
testCase.verifyEqual(measuredSnr, targetSnr, 'AbsTol', 0.5);
end

function test_sampleCount(testCase)
% Số mẫu = K tone + (K-1) khoảng lặng. Viết nhầm (K-1) thành K là thừa
% một khoảng lặng, mọi mốc thời gian trong meta lệch theo.
fs = 8000; toneMs = 100; pauseMs = 50;
keys = '0912345678*#';
K = numel(keys);
nTone  = round(fs * toneMs  / 1000);
nPause = round(fs * pauseMs / 1000);

x = dtmf_generate(keys, 'fs', fs, 'toneMs', toneMs, 'pauseMs', pauseMs);
testCase.verifyEqual(numel(x), K*nTone + (K-1)*nPause);
end

function test_firstOnsetAtZero(testCase)
% Tone đầu tiên phải bắt đầu ngay tại t = 0, và onsets tăng dần.
[~, ~, meta] = dtmf_generate('123', 'fs', 8000);
testCase.verifyEqual(meta.onsets(1), 0);
testCase.verifyTrue(all(diff(meta.onsets) > 0));
end

function test_toneDuration(testCase)
% Tone dài đúng 100 ms kể cả khi đổi fs - bắt lỗi hard-code 800 mẫu.
for fs = [8000 16000]
    [~, ~, meta] = dtmf_generate('159*', 'fs', fs, 'toneMs', 100);
    testCase.verifyEqual(meta.offsets - meta.onsets, ...
        repmat(0.100, 1, 4), 'AbsTol', 1e-12);
end
end

function test_amplitudeNormalization(testCase)
% Đỉnh |x| phải bằng đúng ampl với mọi twistDb. Nếu chuẩn hóa bị đặt trong
% vòng lặp thay vì sau nó, các ca twistDb khác 0 sẽ đỏ.
for twistDb = [0 4 -8]
    for ampl = [0.2 0.5 1.0]
        x = dtmf_generate('7', 'twistDb', twistDb, 'ampl', ampl);
        testCase.verifyEqual(max(abs(x)), ampl, 'AbsTol', 1e-12);
    end
end
end

function test_hum50Snr(testCase)
% Nhánh hum50 cũng phải đạt đúng SNR như AWGN, kể cả ở 0 dB.
x = dtmf_generate('5', 'fs', 8000);
for targetSnr = [0 10 20]
    y = dtmf_addnoise(x, 'snrDb', targetSnr, 'type', 'hum50', 'fs', 8000);
    measuredSnr = 10 * log10(sum(x.^2) / sum((y - x).^2));
    testCase.verifyEqual(measuredSnr, targetSnr, 'AbsTol', 0.5);
end
end
