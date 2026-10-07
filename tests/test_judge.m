function tests = test_judge
%TEST_JUDGE Unit test cho app/dtmf_judge - đối chiếu số thật với số đọc được.
tests = functiontests(localfunctions);
end

function test_exactMatch(testCase)
J = dtmf_judge('0912345678', '0912345678');
testCase.verifyEqual(J.nDung, 10);
testCase.verifyEqual(J.nNham + J.nSot + J.nThua, 0);
testCase.verifyEqual(J.acc, 1);
testCase.verifyEmpty(J.lastError);
testCase.verifyClass(J.lastError, 'char');
end

function test_splitToneReadsTwice(testCase)
% Lỗi hay gặp nhất ở màn giám định: tiếng nói làm một khung giữa tone bị
% loại, dtmf_debounce cắt dải, một lần bấm thành hai chữ số.
J = dtmf_judge('0912', '09912');
testCase.verifyEqual(J.op, {'dung', 'thua', 'dung', 'dung', 'dung'});
testCase.verifyEqual(J.align, ['0-912'; '09912']);
testCase.verifyEqual([J.nDung J.nNham J.nSot J.nThua], [4 0 0 1]);
testCase.verifyEqual(J.editDist, 1);
end

function test_wrongAndMissing(testCase)
J = dtmf_judge('12', '3');
testCase.verifyEqual(J.op, {'sot', 'nham'});
J = dtmf_judge('59', '');
testCase.verifyEqual(J.op, {'sot', 'sot'});
testCase.verifyEqual(J.acc, 0);
end

function test_cleansHumanTypedNumber(testCase)
% Người ta gõ số điện thoại có dấu chấm, gạch, cách: bỏ đi trước khi chấm.
J = dtmf_judge('0912.345-678 9', "09123456789");
testCase.verifyEqual(J.keysTrue, '09123456789');
testCase.verifyEqual(J.nDung, 11);
end

function test_neverThrows(testCase)
% Ký tự lạ là lỗi của dtmf_metrics; ở đây nó thành lastError, không thành ngoại lệ.
J = dtmf_judge('12A', '12');
testCase.verifyNotEmpty(J.lastError);
testCase.verifySize(J.align, [2 0]);
testCase.verifyEqual(J.op, cell(1, 0));
end
