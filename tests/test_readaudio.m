function tests = test_readaudio
%TEST_READAUDIO Unit test cho app/dtmf_readaudio - lối vào "nhập từ file audio".
tests = functiontests(localfunctions);
end

function f = tepTam(testCase, y, fs)
% Ghi y (N×C) ra một tệp WAV tạm, tự xóa sau ca test.
f = [tempname, '.wav'];
testCase.addTeardown(@() delete(f));
audiowrite(f, y, fs);
end

function test_resamplesTo8kAndDecodes(testCase)
% 48 kHz -> 8 kHz đúng số mẫu, và cả ba bộ giải mã đọc lại đúng chuỗi.
keys = '0123456789*#';
x48  = dtmf_generate(keys, 'fs', 48000);
[x, info] = dtmf_readaudio(tepTam(testCase, x48(:), 48000));

testCase.verifySize(x, [1 numel(dtmf_generate(keys))]);
testCase.verifyEqual(info.fsFile, 48000);
testCase.verifyFalse(info.truncated);
testCase.verifyEqual(dtmf_decode_goertzel(x), keys);
testCase.verifyEqual(dtmf_decode_fft(x), keys);
testCase.verifyEqual(dtmf_decode_filterbank(x), keys);
end

function test_stereoIsAveraged(testCase)
% Hai kênh ngược dấu cho trung bình bằng 0 - chứng tỏ hàm lấy trung bình
% chứ không chỉ đọc kênh trái.
x = dtmf_generate('5');
[y, info] = dtmf_readaudio(tepTam(testCase, [x(:), -x(:)], 8000));
testCase.verifyEqual(info.nChannel, 2);
testCase.verifyLessThan(max(abs(y)), 1e-4);
end

function test_longFileIsTruncated(testCase)
% Dài hơn maxSec thì chỉ giữ phần đầu và báo truncated.
[y, info] = dtmf_readaudio(tepTam(testCase, zeros(8000 * 3, 1), 8000), 'maxSec', 1);
testCase.verifySize(y, [1 8000]);
testCase.verifyTrue(info.truncated);
testCase.verifyEqual(info.fileSec, 3);
end

function test_missingFileThrows(testCase)
% Hàm ném lỗi; bắt lỗi là việc của DTMFApp.napTep.
testCase.verifyError(@() dtmf_readaudio(fullfile(tempdir, 'khong_co.wav')), ?MException);
end
