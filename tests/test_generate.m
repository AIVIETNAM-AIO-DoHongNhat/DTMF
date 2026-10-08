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

function test_badInputsThrowNamedErrors(testCase)
% Mỗi đầu vào sai có định danh lỗi riêng. NaN phải bị chặn: mọi phép so với
% NaN đều false, nên chốt viết kiểu "ampl <= 0" sẽ để NaN lọt qua và cho ra
% một tín hiệu toàn NaN.
testCase.verifyError(@() dtmf_generate('5', 'ampl', NaN), 'dtmf_generate:badAmpl');
testCase.verifyError(@() dtmf_generate('5', 'ampl', 1.5), 'dtmf_generate:badAmpl');
testCase.verifyError(@() dtmf_generate('5A'), 'dtmf_generate:unknownKey');
testCase.verifyError(@() dtmf_generate('5', 'toneMs', 0.01), 'dtmf_generate:badToneMs');
testCase.verifyError(@() dtmf_generate('5', 'toneMs', NaN), 'dtmf_generate:badToneMs');
testCase.verifyError(@() dtmf_generate('55', 'pauseMs', -20), 'dtmf_generate:badPauseMs');
testCase.verifyError(@() dtmf_generate('5', 'fs', 0), 'dtmf_generate:badFs');
end

function test_emptyKeysGiveOneByZeroMeta(testCase)
% Chuỗi rỗng hợp lệ; mọi trường rỗng là 1×0 theo CONTRACTS §2, không phải [].
[x, t, meta] = dtmf_generate('');
testCase.verifySize(x, [1 0]);
testCase.verifySize(t, [1 0]);
for f = {'onsets', 'offsets', 'fRow', 'fCol'}
    testCase.verifySize(meta.(f{1}), [1 0], f{1});
end
end

function test_addnoiseRejectsUnknownType(testCase)
% Tên nhiễu gõ sai bị chặn kể cả khi x rỗng (nhánh rỗng trả về sớm).
testCase.verifyError(@() dtmf_addnoise(dtmf_generate('5'), 'type', 'pink'), 'dtmf_addnoise:badType');
testCase.verifyError(@() dtmf_addnoise(zeros(1, 0), 'type', 'pink'), 'dtmf_addnoise:badType');
end

function test_addnoiseSpeechNeedsDataFile(testCase)
% Nhánh 'speech' không tự chuyển sang awgn khi thiếu data/wav/speech_*.wav.
root = fileparts(fileparts(mfilename('fullpath')));
testCase.assumeEmpty(dir(fullfile(root, 'data', 'wav', 'speech_*.wav')), ...
    'Đã có tệp tiếng nói mẫu, ca này chỉ kiểm khi thiếu tệp.');
testCase.verifyError(@() dtmf_addnoise(dtmf_generate('5'), 'type', 'speech'), ...
    'dtmf_addnoise:missingSpeech');
end

function test_addnoiseSpeechHitsTargetSnr(testCase)
% Ca anh em của ca trên: có data/wav/speech_*.wav (make_dataset dựng từ giọng
% tổng đài) thì nhánh 'speech' đạt đúng SNR như hai nhánh kia, và tệp lệch fs
% bị chặn chứ không âm thầm đổi cao độ giọng nói. Hai ca luôn có đúng một ca chạy.
root = fileparts(fileparts(mfilename('fullpath')));
testCase.assumeNotEmpty(dir(fullfile(root, 'data', 'wav', 'speech_*.wav')), ...
    'Chưa có tệp tiếng nói mẫu, chạy make_dataset để có.');
x = dtmf_generate('0912345');
for targetSnr = [0 10 20]
    y = dtmf_addnoise(x, 'snrDb', targetSnr, 'type', 'speech', 'fs', 8000);
    measuredSnr = 10 * log10(sum(x.^2) / sum((y - x).^2));
    testCase.verifyEqual(measuredSnr, targetSnr, 'AbsTol', 0.5);
end
testCase.verifyError(@() dtmf_addnoise(x, 'type', 'speech', 'fs', 16000), ...
    'dtmf_addnoise:speechFsMismatch');
end
