function tests = test_live
%TEST_LIVE Smoke test cho app/DTMFLive - màn tổng đài nghe đường dây.
%
% Chạy ẩn bằng DTMFLive('off'): không nối mạng, không mở micro, không chạy
% đồng hồ. Test đưa tin vào qua nhanTin như DTMFLine.doc trả về, rồi đọc nhãn
% và app.Line.DaGui - danh sách tin MATLAB đã gửi cho điện thoại.
tests = functiontests(localfunctions);
end

function app = moi(testCase)
app = DTMFLive('off');
testCase.addTeardown(@() delete(app));
end

function gui = daGui(app)
% Các tin đã gửi, dạng 'answer', 'key:5', ... cho dễ so.
gui = cellfun(@(m) ten(m), app.Line.DaGui, 'UniformOutput', false);
end

function s = ten(m)
s = m.t;
if isfield(m, 'k')
    s = [s ':' m.k];
end
end

function choAn(app, x)
% Đưa x vào theo đoạn 400 mẫu, như một tick 50 ms của đường dây.
for i = 1:400:numel(x)
    app.nhanTin(struct('t', 'pcm', 'x', x(i:min(i+399, end))));
end
end

function test_hiddenWindowStartsWaiting(testCase)
app = moi(testCase);
testCase.verifyEqual(app.UIFigure.Visible, matlab.lang.OnOffSwitchState('off'));
testCase.verifyEqual(app.CuocGoi, 'cho');
testCase.verifyFalse(app.Line.DaNoi);
testCase.verifyEqual(app.BtnHangup.Enable, matlab.lang.OnOffSwitchState('off'));
end

function test_callRingsThenAnswersAndReportsEveryKey(testCase)
% Gọi -> đổ chuông -> nhấc máy -> mỗi phím đọc được gửi về điện thoại đúng
% thứ tự, không thiếu không thừa.
app = moi(testCase);
app.nhanTin(struct('t', 'call'));
testCase.verifyEqual(app.CuocGoi, 'chuong');
testCase.verifyEqual(app.BtnHangup.Enable, matlab.lang.OnOffSwitchState('on'));

app.nhacMay();
testCase.verifyEqual(app.CuocGoi, 'noi');

choAn(app, [dtmf_generate('0912345*#'), zeros(1, 800)]);
testCase.verifyEqual(app.DaySo, '0912345*#');
testCase.verifyEqual(app.LblNumber.Text, '0912345*#');
testCase.verifyEqual(daGui(app), ...
    {'answer', 'key:0', 'key:9', 'key:1', 'key:2', 'key:3', 'key:4', 'key:5', 'key:*', 'key:#'});
end

function test_answersAfterRingingTime(testCase)
% nhip tự nhấc máy khi đã đổ chuông đủ GIO_CHUONG = 1,5 s, không sớm hơn.
app = moi(testCase);
app.nhanTin(struct('t', 'call'));
app.nhip();
testCase.verifyEqual(app.CuocGoi, 'chuong');
pause(1.6);
app.nhip();
testCase.verifyEqual(app.CuocGoi, 'noi');
testCase.verifyEqual(daGui(app), {'answer'});
end

function test_keysWhileRingingAreNotReported(testCase)
% Phím vang lên lúc còn đổ chuông: điện thoại chưa vào menu nào, không gửi.
app = moi(testCase);
app.nhanTin(struct('t', 'call'));
choAn(app, [dtmf_generate('7'), zeros(1, 800)]);
testCase.verifyEmpty(app.DaySo);
testCase.verifyEmpty(app.Line.DaGui);
end

function test_hangupFromPhoneEndsTheCall(testCase)
app = moi(testCase);
app.nhanTin(struct('t', 'call'));
app.nhacMay();
choAn(app, [dtmf_generate('42'), zeros(1, 800)]);
app.nhanTin(struct('t', 'hangup'));
testCase.verifyEqual(app.CuocGoi, 'xong');
testCase.verifyEqual(app.BtnHangup.Enable, matlab.lang.OnOffSwitchState('off'));
testCase.verifyTrue(contains(app.LblClock.Text, '2 phím'));
% Điện thoại tự gác máy thì MATLAB không gửi hangup ngược lại.
testCase.verifyFalse(any(strcmp(daGui(app), 'hangup')));
end

function test_hangupButtonTellsThePhone(testCase)
app = moi(testCase);
app.nhanTin(struct('t', 'call'));
app.nhacMay();
app.BtnHangupPushed([]);
testCase.verifyEqual(app.CuocGoi, 'xong');
testCase.verifyEqual(daGui(app), {'answer', 'hangup'});
end

function test_newCallStartsClean(testCase)
% Cuộc gọi sau không mang phím của cuộc gọi trước.
app = moi(testCase);
app.nhanTin(struct('t', 'call'));
app.nhacMay();
choAn(app, [dtmf_generate('11'), zeros(1, 800)]);
app.nhanTin(struct('t', 'hangup'));
app.nhanTin(struct('t', 'call'));
testCase.verifyEmpty(app.DaySo);
testCase.verifyEmpty(app.L.keysHat);
end

function test_methodChangeKeepsKeysAndAllMethodsDecode(testCase)
% Đổi bộ giải mã giữa cuộc gọi: giữ phím cũ, phím sau đọc bằng phương pháp mới.
app = moi(testCase);
app.nhanTin(struct('t', 'call'));
app.nhacMay();
choAn(app, [dtmf_generate('12'), zeros(1, 800)]);
for m = {'fft', 'filterbank', 'goertzel'}
    app.DdMethod.Value = m{1};
    app.DdMethodValueChanged([]);
    testCase.verifyEqual(app.L.method, m{1});
    choAn(app, [dtmf_generate('3'), zeros(1, 800)]);
end
testCase.verifyEqual(app.DaySo, '12333');
% Mỗi lần đổi, MATLAB báo cầu nối tên phương pháp mới.
testCase.verifyEqual(nnz(strcmp(daGui(app), 'hello')), 3);
end

function test_micSourceDecodesWithoutCall(testCase)
% Nguồn micro không có cuộc gọi: bật là nghe, phím hiện ngay, không gửi gì.
app = moi(testCase);
app.BtnSrcPushed(struct('Source', app.BtnSrcMic));
testCase.verifyEqual(app.Nguon, 'mic');
testCase.verifyEqual(app.CuocGoi, 'tat');
app.BtnRunPushed([]);
testCase.verifyEqual(app.CuocGoi, 'nghe');
% Chạy ẩn thì không có micro thật: đưa mẫu thẳng vào như một tick.
app.nhanTin(struct('t', 'pcm', 'x', [dtmf_generate('86'), zeros(1, 800)]));
testCase.verifyEqual(app.DaySo, '86');
testCase.verifyEmpty(app.Line.DaGui);
end

function test_drawKeepsUpWithTheLine(testCase)
% Một tick có vẽ phải xong trong vài chục ms để theo kịp đồng hồ 50 ms.
% Ngưỡng nới rộng cho máy chậm và cửa sổ ẩn; đo thật ở CONTRACTS §7.10.
app = moi(testCase);
app.nhanTin(struct('t', 'call'));
app.nhacMay();
choAn(app, [dtmf_generate('5'), zeros(1, 400)]);
pause(0.11);
t0 = tic;
app.nhip();
testCase.verifyLessThan(toc(t0), 0.5);
end
