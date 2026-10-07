function tests = test_line
%TEST_LINE Unit test cho app/DTMFLine - đầu MATLAB của đường dây tới trang web.
%
% Test chạy không cần cầu nối thật: phần tách byte thành tin là hàm tĩnh
% DTMFLine.tachTin, còn gửi khi chưa nối chỉ ghi vào DaGui. Đường đi đầy đủ
% (trình duyệt -> cầu nối Vite -> MATLAB) đã thử tay ngày 06/10/2026, xem
% CONTRACTS §7.10.
tests = functiontests(localfunctions);
end

function b = dong(s)
% Một dòng JSON như cầu nối gửi, dạng uint8.
b = [unicode2native(s, 'UTF-8'), uint8(10)];
end

function d = pcm64(x)
% Mẫu [-1, 1] -> base64 của int16 little-endian, như trang web gửi.
d = matlab.net.base64encode(typecast(int16(round(32767 * x)), 'uint8'));
end

function test_splitsLinesAndKeepsTheTail(testCase)
% Dòng cuối chưa có '\n' được giữ lại, ghép với lần đọc sau.
b = [dong('{"t":"ping"}'), dong('{"t":"call"}'), unicode2native('{"t":"hang', 'UTF-8')];
[tin, du] = DTMFLine.tachTin(uint8([]), b);
testCase.verifyEqual(numel(tin), 2);
testCase.verifyEqual(tin{1}.t, 'ping');
testCase.verifyEqual(tin{2}.t, 'call');

[tin, du] = DTMFLine.tachTin(du, dong('up"}'));
testCase.verifyEqual(numel(tin), 1);
testCase.verifyEqual(tin{1}.t, 'hangup');
testCase.verifyEmpty(du);
end

function test_pcmRoundTripsAndMergesNeighbours(testCase)
% Hai tin pcm liền nhau gộp thành một, đúng thứ tự mẫu; tin điều khiển ở
% giữa thì cắt đôi chúng.
x = dtmf_generate('5');
a = x(1:300);
b = x(301:end);
bytes = [dong(sprintf('{"t":"pcm","d":"%s"}', pcm64(a))), ...
         dong(sprintf('{"t":"pcm","d":"%s"}', pcm64(b))), ...
         dong('{"t":"hangup"}'), ...
         dong(sprintf('{"t":"pcm","d":"%s"}', pcm64(a)))];
tin = DTMFLine.tachTin(uint8([]), bytes);

testCase.verifyEqual(cellfun(@(m) m.t, tin, 'UniformOutput', false), {'pcm', 'hangup', 'pcm'});
testCase.verifyEqual(tin{1}.x, x, 'AbsTol', 1 / 32767);
testCase.verifyEqual(tin{3}.x, a, 'AbsTol', 1 / 32767);
end

function test_badLinesAreSkipped(testCase)
% Dòng hỏng không làm mất các dòng đúng sau nó; byte lẻ ở cuối pcm bị bỏ.
bytes = [dong('không phải json'), dong('{"khong":"co t"}'), dong(''), ...
         dong('{"t":"pcm","d":"AQACAAM="}'), dong('{"t":"call"}')];
tin = DTMFLine.tachTin(uint8([]), bytes);
testCase.verifyEqual(numel(tin), 2);
testCase.verifyEqual(tin{1}.x * 32767, [1 2], 'AbsTol', 1e-9);
testCase.verifyEqual(tin{2}.t, 'call');
end

function test_sendWithoutBridgeOnlyRecords(testCase)
% Chưa nối thì gửi không ném lỗi, chỉ ghi vào DaGui (giữ 50 tin cuối).
line = DTMFLine();
testCase.verifyFalse(line.DaNoi);
testCase.verifyFalse(line.conSong());
testCase.verifyEqual(line.doc(), {});
for k = 1:60
    line.gui(struct('t', 'key', 'k', '5', 'n', k));
end
testCase.verifyEqual(numel(line.DaGui), 50);
testCase.verifyEqual(line.DaGui{end}.n, 60);
end
