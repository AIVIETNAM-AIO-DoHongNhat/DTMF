function tests = test_forensic
%TEST_FORENSIC Smoke test cho app/DTMFForensic - màn giám định ghi âm.
%
% Chạy ẩn bằng DTMFForensic('off'): không nối mạng, không mở micro, không
% chạy đồng hồ. Test đưa tin vào qua nhanTin đúng như DTMFLine.doc trả về,
% rồi đọc thuộc tính, nhãn và app.Line.DaGui - các tin MATLAB đã gửi trang.
tests = functiontests(localfunctions);
end

function app = moi(testCase)
app = DTMFForensic('off');
testCase.addTeardown(@() delete(app));
end

function gui = daGui(app)
% Các tin đã gửi, dạng 'verdict', 'key:5', ... cho dễ so.
gui = cellfun(@(m) ten(m), app.Line.DaGui, 'UniformOutput', false);
end

function s = ten(m)
s = m.t;
if isfield(m, 'k')
    s = [s ':' m.k];
end
end

function [x, marks] = doan(keys)
% Một đoạn ghi âm như trang gửi: 0,5 s lặng, các phím 100/50 ms, 0,4 s lặng.
% marks: [đầu1 cuối1 đầu2 ...] như tin reveal.
[xk, ~, meta] = dtmf_generate(keys);
x = [zeros(1, 4000), xk, zeros(1, 3200)];
marks = reshape([meta.onsets; meta.offsets] + 0.5, 1, []);
end

function choAn(app, x)
% Đưa x vào theo đoạn 400 mẫu, như một tick 50 ms của đường dây.
for i = 1:400:numel(x)
    app.nhanTin(struct('t', 'pcm', 'x', x(i:min(i+399, end))));
end
end

function test_hiddenWindowWaits(testCase)
app = moi(testCase);
testCase.verifyEqual(app.Ho, 'cho');
testCase.verifyFalse(app.Line.DaNoi);
testCase.verifyEqual(app.BtnReveal.Enable, matlab.lang.OnOffSwitchState('off'));
end

function test_fullCaseOverTheLine(testCase)
% case -> âm thanh -> end -> verdict -> reveal: luồng chính của buổi trình diễn.
app = moi(testCase);
[x, marks] = doan('0912345678');
app.nhanTin(struct('t', 'case', 'id', 7, 'sec', numel(x) / 8000));
testCase.verifyEqual(app.Ho, 'nghe');
testCase.verifyEqual(app.SoVu, 7);
testCase.verifyEqual(app.DdMethod.Enable, matlab.lang.OnOffSwitchState('off'));

choAn(app, x);
% Đọc dần: mỗi phím báo về trang ngay khi nghe ra, trước khi hết đoạn.
testCase.verifyEqual(app.DaySo, '0912345678');
testCase.verifyEqual(daGui(app), arrayfun(@(k) ['key:' k], '0912345678', 'UniformOutput', false));

app.nhanTin(struct('t', 'end'));
testCase.verifyEqual(app.Ho, 'ketluan');
testCase.verifyEqual({app.KetQua.method}, {'goertzel', 'fft', 'filterbank'});
testCase.verifyEqual({app.KetQua.keys}, repmat({'0912345678'}, 1, 3));
testCase.verifyTrue(all([app.KetQua.ms] > 0));
v = app.Line.DaGui{end};
testCase.verifyEqual(v.t, 'verdict');
testCase.verifyEqual(v.keys, '0912345678');
testCase.verifyNumElements(v.methods, 3);
% Tin kết luận phải thành JSON mà trang đọc được (web/src/line/protocol.ts).
j = jsondecode(jsonencode(v));
testCase.verifyEqual({j.methods.name}', {'Goertzel'; 'FFT'; 'Ngân hàng bộ lọc'});
testCase.verifyEqual(app.LblNumber.Text, '0912345678');
testCase.verifyEqual(app.BtnReveal.Enable, matlab.lang.OnOffSwitchState('on'));

app.nhanTin(struct('t', 'reveal', 'keys', '0912345678', 'marks', marks));
testCase.verifyEqual(app.Ho, 'doichieu');
testCase.verifyEqual([app.DoiChieu.editDist], [0 0 0]);
testCase.verifyTrue(contains(app.LblVerdict.Text, 'khớp cả 10 chữ số'));
testCase.verifyTrue(contains(app.LblCase.Text, 'khớp'));
% Làn số thật: mười lần bấm, đúng mốc trang gửi, đều xanh.
testCase.verifyEqual(app.That.k, '0912345678');
testCase.verifyEqual(app.That.t0, marks(1:2:end));
testCase.verifyTrue(all(app.That.dung));
end

function test_revealShowsWhichDigitWentWrong(testCase)
% MATLAB đọc '0912' mà số thật là '0915': chữ số cuối nhầm, tô đỏ trên làn.
app = moi(testCase);
[x, marks] = doan('0912');
app.nhanTin(struct('t', 'case', 'id', 1, 'sec', numel(x) / 8000));
choAn(app, x);
app.nhanTin(struct('t', 'end'));
app.nhanTin(struct('t', 'reveal', 'keys', '0915', 'marks', marks));
J = app.DoiChieu(1);
testCase.verifyEqual(J.op, {'dung', 'dung', 'dung', 'nham'});
testCase.verifyEqual(app.That.dung, [true true true false]);
testCase.verifyTrue(contains(app.LblVerdict.Text, 'lệch 1: 1 nhầm'));
testCase.verifyTrue(contains(app.LblMethods.Text, 'lệch 1'));
end

function test_revealBeforeVerdictConcludesFirst(testCase)
% Đáp án không bao giờ đi trước kết luận: reveal tới lúc còn nghe thì MATLAB
% kết luận trên phần đã nghe rồi mới đối chiếu.
app = moi(testCase);
[x, ~] = doan('42');
app.nhanTin(struct('t', 'case', 'id', 1, 'sec', 1));
choAn(app, x);
app.nhanTin(struct('t', 'reveal', 'keys', '42', 'marks', []));
testCase.verifyEqual(app.Ho, 'doichieu');
gui = daGui(app);
testCase.verifyTrue(any(strcmp(gui, 'verdict')));
testCase.verifyEmpty(app.That);
end

function test_newCaseStartsClean(testCase)
app = moi(testCase);
[x, ~] = doan('11');
app.nhanTin(struct('t', 'case', 'id', 1, 'sec', 1));
choAn(app, x);
app.nhanTin(struct('t', 'end'));
app.nhanTin(struct('t', 'reveal', 'keys', '11', 'marks', []));
app.nhanTin(struct('t', 'case', 'id', 2, 'sec', 1));
testCase.verifyEqual(app.Ho, 'nghe');
testCase.verifyEmpty(app.DaySo);
testCase.verifyEmpty(app.KetQua);
testCase.verifyEmpty(app.DoiChieu);
testCase.verifyEmpty(app.That);
testCase.verifyEmpty(app.Y);
end

function test_pageClosingMidCaseCancelsIt(testCase)
app = moi(testCase);
[x, ~] = doan('5');
app.nhanTin(struct('t', 'case', 'id', 1, 'sec', 1));
choAn(app, x(1:2000));
app.nhanTin(struct('t', 'hangup'));
testCase.verifyEqual(app.Ho, 'cho');
testCase.verifyTrue(contains(app.LblHint.Text, 'ngắt giữa chừng'));
% Mẫu tới sau khi hủy không mở lại vụ nào.
choAn(app, x(2001:end));
testCase.verifyEmpty(app.DaySo);
end

function test_badTypedTruthIsReportedNotThrown(testCase)
app = moi(testCase);
[x, ~] = doan('7');
app.nhanTin(struct('t', 'case', 'id', 1, 'sec', 1));
choAn(app, x);
app.nhanTin(struct('t', 'end'));
app.EfTruth.Value = '7A';
app.BtnRevealPushed([]);
testCase.verifyEqual(app.Ho, 'ketluan');
testCase.verifyTrue(contains(app.LblHint.Text, 'không hợp lệ'));
end

function test_micSourceManualCase(testCase)
% Không có trang web: bấm Bắt đầu nghe, cho mẫu vào (thay cho micro), bấm
% Kết luận, gõ số thật vào ô rồi đối chiếu. Mẫu từ đường dây bị bỏ qua.
app = moi(testCase);
app.BtnSrcPushed(struct('Source', app.BtnSrcMic));
testCase.verifyEqual(app.Nguon, 'mic');
testCase.verifyEqual(app.BtnRun.Text, 'Bắt đầu nghe');
app.BtnRunPushed([]);
testCase.verifyEqual(app.Ho, 'nghe');
testCase.verifyEqual(app.SoVu, 1);
testCase.verifyEqual(app.BtnRun.Text, 'Kết luận');

choAn(app, doan('99'));            % như trang gửi: phải bị bỏ qua
testCase.verifyEmpty(app.DaySo);
[x, ~] = doan('86');
app.nhanMau(x);                    % như micro thu được
testCase.verifyEqual(app.DaySo, '86');

app.BtnRunPushed([]);
testCase.verifyEqual(app.Ho, 'ketluan');
app.EfTruth.Value = '8 6';
app.BtnRevealPushed([]);
testCase.verifyEqual(app.Ho, 'doichieu');
testCase.verifyEqual(app.DoiChieu(1).nDung, 2);
end

function test_lineEndInMicModeWaitsForTheTail(testCase)
% Nguồn micro, trang điều khiển: 'end' không kết luận ngay mà chờ TRE_MIC
% giây để micro thu nốt phần còn bay trong không khí.
app = moi(testCase);
app.BtnSrcPushed(struct('Source', app.BtnSrcMic));
app.nhanTin(struct('t', 'case', 'id', 3, 'sec', 1));
[x, ~] = doan('3');
app.nhanMau(x);
app.nhanTin(struct('t', 'end'));
testCase.verifyEqual(app.Ho, 'nghe');
pause(0.5);
app.nhip();
testCase.verifyEqual(app.Ho, 'ketluan');
testCase.verifyEqual(app.KetQua(1).keys, '3');
end

function test_methodChoiceDrivesTheVerdict(testCase)
% Kết luận gửi trang là của bộ giải mã đang chọn; ô chọn bị khóa lúc nghe.
app = moi(testCase);
app.DdMethod.Value = 'filterbank';
app.DdMethodValueChanged([]);
testCase.verifyEqual(app.Line.DaGui{end}.method, 'Ngân hàng bộ lọc');
testCase.verifyEqual(app.Line.DaGui{end}.app, 'forensic');
[x, ~] = doan('*0#');
app.nhanTin(struct('t', 'case', 'id', 1, 'sec', 1));
testCase.verifyEqual(app.L.method, 'filterbank');
choAn(app, x);
app.nhanTin(struct('t', 'end'));
testCase.verifyEqual(app.Line.DaGui{end}.keys, '*0#');
end

function test_drawKeepsUpWithTheLine(testCase)
% Một tick có vẽ phải xong nhanh để theo kịp đồng hồ 50 ms, kể cả khi cửa sổ
% luồng dài 15 s. Ngưỡng nới rộng cho máy chậm và cửa sổ ẩn.
app = moi(testCase);
app.nhanTin(struct('t', 'case', 'id', 1, 'sec', 15));
choAn(app, [dtmf_generate('0912345678'), zeros(1, 8000)]);
pause(0.11);
t0 = tic;
app.nhip();
testCase.verifyLessThan(toc(t0), 0.5);
end
