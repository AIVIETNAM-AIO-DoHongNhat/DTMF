function tests = test_app_smoke
%TEST_APP_SMOKE Kiểm giao diện DTMFApp dựng, bấm và giải mã được headless.
%
% Chạy trong matlab -batch nên app phải dựng bằng DTMFApp('off') và phải được
% hủy bằng addTeardown: cửa sổ sót lại làm ca sau đếm nhầm số figure.
%
% Không có API công khai nào để "bấm" một uibutton bằng code, nên test gọi
% thẳng callback - đó là lý do sáu callback của DTMFApp để public.
%
tests = functiontests(localfunctions);
end

function app = newApp(testCase)
% Giao diện ẩn, tự hủy khi ca test kết thúc.
app = DTMFApp('off');
testCase.addTeardown(@() delete(app));
end

function app = appDaSinh(testCase, keys, snrDb)
% App đã bấm "Phát tín hiệu" một lần - điểm xuất phát của hầu hết các ca.
rng(2026);
app = newApp(testCase);
app.EfKeys.Value = keys;
app.SldSNR.Value = snrDb;
app.BtnGenPushed([]);
end

function nhan = banPhim()
% Bảng tên property <-> ký tự, đóng băng theo docs/ui_naming.md §2.
nhan = {'Btn1', '1'; 'Btn2', '2'; 'Btn3', '3'
        'Btn4', '4'; 'Btn5', '5'; 'Btn6', '6'
        'Btn7', '7'; 'Btn8', '8'; 'Btn9', '9'
        'BtnStar', '*'; 'Btn0', '0'; 'BtnHash', '#'};
end

% ------------------------------------------------------------------ dựng hình

function test_buildsEveryComponentInNamingDoc(testCase)
% docs/ui_naming.md là hợp đồng đặt tên; thiếu một component thì callback hoặc
% ui_refresh gọi vào một property rỗng và chỉ đổ vỡ lúc chạy demo.
app = newApp(testCase);

bp  = banPhim();
ten = [bp(:, 1)', {'UIFigure', 'PnlKeypad', 'AxWave', 'AxSpec', 'AxBars', ...
                   'EfKeys', 'DdMethod', 'SldSNR', 'BtnGen', 'BtnDecode', ...
                   'BtnPlay', 'LblDecoded', 'TxtLog', 'BtnSrcGen', 'BtnSrcMic', ...
                   'PnlMic', 'BtnRecord', 'BtnListen'}];
for t = ten
    testCase.verifyTrue(isprop(app, t{1}), sprintf('Thiếu property %s.', t{1}));
    testCase.verifyTrue(isvalid(app.(t{1})), sprintf('%s không dựng được.', t{1}));
end
end

function test_controlSettingsMatchNamingDoc(testCase)
% Bốn thiết lập này là hợp đồng, không phải sở thích: ItemsData phải khớp sẵn
% S.method (nếu không switch trong dtmf_run rơi hết vào nhánh otherwise),
% Limits khớp dải SNR mà run_bench quét, và TxtLog phải chỉ đọc.
app = newApp(testCase);

testCase.verifyEqual(app.DdMethod.ItemsData, {'fft', 'goertzel', 'filterbank'});
testCase.verifyEqual(app.SldSNR.Limits, [-5 30]);
testCase.verifyEqual(char(app.TxtLog.Editable), 'off');
testCase.verifyNumElements(app.DdMethod.Items, 3);
end

function test_keypadButtonsAreWiredAndLabelled(testCase)
% Cả 12 nút dùng CHUNG một callback và phân biệt nhau bằng event.Source.Text.
% Gán nhầm Text cho một nút là lỗi im lặng: nút vẫn bấm được, vẫn thêm một ký
% tự, chỉ là sai ký tự.
app = newApp(testCase);
bp = banPhim();

for i = 1:size(bp, 1)
    nut = app.(bp{i, 1});
    testCase.verifyEqual(nut.Text, bp{i, 2}, ...
        sprintf('%s mang nhãn %s.', bp{i, 1}, nut.Text));
    testCase.verifyNotEmpty(nut.ButtonPushedFcn, ...
        sprintf('%s chưa nối callback.', bp{i, 1}));
end
end

function test_hiddenAppPopsNoWindow(testCase)
% Một cửa sổ bật lên giữa matlab -batch làm treo phiên chạy, và giữa buổi demo
% thì che mất giao diện thật.
n0 = numel(findall(groot, 'Type', 'figure'));
app = newApp(testCase);

testCase.verifyEqual(numel(findall(groot, 'Type', 'figure')), n0 + 1);
testCase.verifyEqual(char(app.UIFigure.Visible), 'off');
end

function test_constructorDrawsEmptyState(testCase)
% Constructor gọi ui_refresh một lần: ba trục phải có tiêu đề "chưa có tín
% hiệu" thay vì ba ô trắng không rõ là đang hỏng hay đang chờ.
app = newApp(testCase);

testCase.verifyNotEmpty(app.AxWave.Title.String);
testCase.verifyNotEmpty(app.AxSpec.Title.String);
testCase.verifyNotEmpty(app.AxBars.Title.String);
testCase.verifyEmpty(app.LblDecoded.Text);
end

function test_deleteClosesTheFigure(testCase)
% delete(app) phải đóng cửa sổ, nếu không mỗi lần chạy thử để lại một figure
% treo và lần chạy sau đếm sai.
app = DTMFApp('off');
f = app.UIFigure;
delete(app);
testCase.verifyFalse(isvalid(f));
end

% -------------------------------------------------------------- luồng đầy đủ

function test_headlessRoundTripAllThreeMethods(testCase)
% Ca quan trọng nhất cả file: gõ phím -> sinh tín hiệu -> giải mã -> đọc lại
% đúng chuỗi ban đầu, cho CẢ BA phương pháp. Đây chính là buổi demo.
app = appDaSinh(testCase, '0912345', 25);

for m = {'fft', 'goertzel', 'filterbank'}
    app.DdMethod.Value = m{1};
    app.BtnDecodePushed([]);

    testCase.verifyEqual(app.LblDecoded.Text, '0912345', ...
        sprintf('Nhánh %s đọc ra "%s".', m{1}, app.LblDecoded.Text));
    testCase.verifyEmpty(app.S.lastError, ...
        sprintf('Nhánh %s báo lỗi: %s', m{1}, app.S.lastError));
end
end

function test_generateFillsSignalWithoutDecoding(testCase)
% "Phát tín hiệu" và "Giải mã" là hai việc tách bạch: nút Phát chỉ dựng x, y,
% meta chứ chưa đụng tới bộ giải mã.
app = appDaSinh(testCase, '0912345', 25);

testCase.verifyEqual(app.S.meta.keys, '0912345');
testCase.verifyNumElements(app.S.x, 7*800 + 6*400);
testCase.verifyNumElements(app.S.y, numel(app.S.x));
testCase.verifyNotEqual(app.S.y, app.S.x);        % đã cộng nhiễu
testCase.verifyEmpty(app.LblDecoded.Text);        % nhưng chưa giải mã
end

function test_generateClearsThePreviousResult(testCase)
% Đổi chuỗi phím rồi bấm Phát mà nhãn kết quả cũ còn nguyên thì người xem
% tưởng máy vừa giải mã đúng chuỗi mới. Đây là lỗi hiểu nhầm, không phải lỗi
% kỹ thuật - và nó xảy ra ngay trước mắt người chấm.
app = appDaSinh(testCase, '0912345', 25);
app.BtnDecodePushed([]);
testCase.verifyEqual(app.LblDecoded.Text, '0912345');

app.EfKeys.Value = '456';
app.BtnGenPushed([]);

testCase.verifyEmpty(app.LblDecoded.Text);
testCase.verifyEqual(app.S.iSel, 0);
testCase.verifyEmpty(findobj(app.AxBars, 'Type', 'bar'));
end

function test_methodDropdownRedecodesOnChange(testCase)
% Đổi phương pháp phải thấy kết quả đổi theo ngay, không phải bấm Giải mã lần
% nữa - người chấm sẽ đổi qua đổi lại ba phương pháp để so sánh.
app = appDaSinh(testCase, '0912345', 25);
app.DdMethod.Value = 'filterbank';
app.DdMethodValueChanged([]);

testCase.verifyEqual(app.LblDecoded.Text, '0912345');
testCase.verifyEqual(app.S.method, 'filterbank');
end

% ---------------------------------------------------------------- thanh SNR

function test_snrSliderReusesTheSameCleanSignal(testCase)
% Kéo SNR chỉ được cộng lại nhiễu lên ĐÚNG x cũ, giữ nguyên ý "cùng một tín
% hiệu, chỉ khác mức nhiễu" - chỗ dựa để nói về vách SNR ở CONTRACTS §7.2.
%
% So x trước với x sau là VÔ NGHĨA: dtmf_generate tất định nên sinh lại cùng
% chuỗi phím cho đúng cùng một mảng, và một bản sinh lại lọt qua hết. Khác
% biệt thật lộ ra ở đây: người dùng gõ chuỗi mới nhưng CHƯA bấm Phát tín hiệu.
% Nếu thanh trượt sinh lại x thì tín hiệu đổi sau lưng người dùng trong khi
% meta vẫn của chuỗi cũ - dạng sóng và nhãn phím trên AxWave lệch nhau mà
% không có lỗi nào. Đột biến "congNhieu sinh lại x" thoát được bản test cũ.
app = appDaSinh(testCase, '0912345', 25);
xTruoc = app.S.x;
yTruoc = app.S.y;

app.EfKeys.Value = '456';            % gõ chuỗi mới, CHƯA bấm Phát tín hiệu
app.SldSNR.Value = 5;
app.SldSNRValueChanged([]);

testCase.verifyEqual(app.S.x, xTruoc);
testCase.verifyEqual(app.S.meta.keys, '0912345');
testCase.verifyEqual(app.S.snrDb, 5);
testCase.verifyNotEqual(app.S.y, yTruoc);

% Và mức nhiễu thật phải khớp con số trên thanh trượt.
snrDo = 10*log10(mean(xTruoc.^2) / mean((app.S.y - xTruoc).^2));
testCase.verifyEqual(snrDo, 5, 'AbsTol', 0.5);
end

function test_snrSliderRedecodesWithoutPressingDecode(testCase)
% Kéo thanh trượt rồi thấy chuỗi đọc được đổi theo tại chỗ - đó là cái làm
% vách SNR trở nên nhìn thấy được trong buổi demo.
app = appDaSinh(testCase, '0912345', 25);
testCase.verifyEmpty(app.LblDecoded.Text);

app.SldSNR.Value = 28;
app.SldSNRValueChanged([]);

testCase.verifyEqual(app.LblDecoded.Text, '0912345');
testCase.verifyEmpty(app.S.lastError);
end

% ------------------------------------------------------------------ bàn phím

function test_keypadAppendsItsOwnCharacter(testCase)
% Bấm lần lượt 12 nút phải ra đúng 12 ký tự theo đúng thứ tự. Nối qua
% ButtonPushedFcn thật để kiểm luôn dây nối, không chỉ kiểm thân callback.
app = newApp(testCase);
bp  = banPhim();

for i = 1:size(bp, 1)
    nut = app.(bp{i, 1});
    nut.ButtonPushedFcn(nut, struct('Source', nut));
end

testCase.verifyEqual(app.EfKeys.Value, '123456789*0#');
end

function test_keypadIsSilentWhenHidden(testCase)
% Giao diện ẩn thì KHÔNG được đụng tới thiết bị âm thanh: sound() trong
% matlab -batch có thể treo cả phiên chạy test. Và không được ghi nhật ký gì,
% vì im lặng lúc này là đúng chứ không phải sự cố.
app = newApp(testCase);

testCase.verifyWarningFree(@() app.Btn1Pushed(struct('Source', app.Btn5)));
testCase.verifyEqual(app.EfKeys.Value, '5');
testCase.verifyTrue(all(strlength(string(app.TxtLog.Value)) == 0));
end

function test_playButtonIsSilentWhenHidden(testCase)
app = appDaSinh(testCase, '59', 25);

testCase.verifyWarningFree(@() app.BtnPlayPushed([]));
testCase.verifyTrue(all(strlength(string(app.TxtLog.Value)) == 0));
end

% ------------------------------------------------------------------ micro
%
% Chạy ẩn thì app KHÔNG mở micro (lý do như sound() ở trên), nên các ca dưới
% đây đưa âm thanh tổng hợp vào qua hai lối vào công khai: nhanMauMic (tick
% của chế độ nghe) và napBanGhi (bản ghi khi dừng ghi âm). Bản thân phép giải
% mã theo luồng được thử kỹ ở test_listen; ở đây chỉ thử phần điều phối.

function test_micButtonsExistAndStartIdle(testCase)
app = newApp(testCase);

for t = {'BtnRecord', 'BtnListen'}
    testCase.verifyTrue(isvalid(app.(t{1})), t{1});
    testCase.verifyNotEmpty(app.(t{1}).ButtonPushedFcn, t{1});
    testCase.verifyEqual(char(app.(t{1}).Enable), 'on', t{1});
end
end

function test_listenModeShowsKeysWhileFeeding(testCase)
% Bấm "Giải mã trực tiếp", đưa tín hiệu vào từng đoạn 50 ms như tick thật:
% phím phải hiện ra NGAY trong lúc nghe, trước khi bấm dừng. Trong lúc nghe,
% không đổi được nguồn và nút micro còn lại bị khóa.
app = newApp(testCase);
app.BtnSrcPushed(struct('Source', app.BtnSrcMic));
app.BtnListenPushed([]);

testCase.verifyEqual(char(app.BtnSrcGen.Enable), 'off');
testCase.verifyEqual(char(app.BtnRecord.Enable), 'off');
testCase.verifyEqual(char(app.BtnListen.Enable), 'on');
testCase.verifyEqual(char(app.BtnPlay.Enable), 'off');

y = dtmf_generate('0912345');
for i = 1:400:numel(y)
    app.nhanMauMic(y(i:min(i+399, end)));
end
testCase.verifyEqual(app.LblDecoded.Text, '0912345');

app.BtnListenPushed([]);
testCase.verifyEqual(char(app.BtnSrcGen.Enable), 'on');
testCase.verifyEqual(char(app.BtnRecord.Enable), 'on');
testCase.verifyEqual(app.LblDecoded.Text, '0912345');
end

function test_listenLabelKeepsOnlyTheLastTwelveKeys(testCase)
% Nhãn "Đọc được" chỉ vừa ~12 ký tự; nghe lâu thì phải thấy phím MỚI NHẤT,
% không phải 12 phím đầu còn phím mới bị cắt khỏi mép phải.
app = newApp(testCase);
app.BtnListenPushed([]);

keys = '0123456789*#0123';
y = dtmf_generate(keys);
for i = 1:400:numel(y)
    app.nhanMauMic(y(i:min(i+399, end)));
end
testCase.verifyEqual(app.LblDecoded.Text, keys(end-11:end));
testCase.verifySubstring(app.LblStatus.Text, sprintf('%d phím', numel(keys)));
end

function test_methodChangeWhileListeningKeepsKeys(testCase)
app = newApp(testCase);
app.BtnListenPushed([]);
y = dtmf_generate('12');
for i = 1:400:numel(y)
    app.nhanMauMic(y(i:min(i+399, end)));
end

app.DdMethod.Value = 'filterbank';
app.DdMethodValueChanged([]);
y = dtmf_generate('3');
for i = 1:400:numel(y)
    app.nhanMauMic(y(i:min(i+399, end)));
end

testCase.verifyEqual(app.LblDecoded.Text, '123');
testCase.verifySubstring(app.LblStatus.Text, 'Ngân hàng bộ lọc');
end

function test_samplesAreIgnoredWhenNotListening(testCase)
% Tick muộn tới sau khi đã bấm dừng không được làm đổi kết quả.
app = newApp(testCase);
testCase.verifyWarningFree(@() app.nhanMauMic(dtmf_generate('5')));
testCase.verifyEmpty(app.LblDecoded.Text);
end

function test_recordingIsDecodedAndKeptWhenSnrMoves(testCase)
% Bản ghi micro không có tín hiệu sạch x: kéo thanh SNR mà cộng lại nhiễu từ
% x rỗng thì bản ghi biến mất ngay trước mắt người chấm.
app = newApp(testCase);
y = dtmf_addnoise(dtmf_generate('0912345'), 'snrDb', 20);
app.napBanGhi(y);

testCase.verifyEqual(app.LblDecoded.Text, '0912345');
testCase.verifyEqual(app.LblSent.Text, '(micro)');

app.SldSNR.Value = 0;
app.SldSNRValueChanged([]);
testCase.verifyEqual(app.S.y, y);
testCase.verifyEqual(app.LblDecoded.Text, '0912345');
end

function test_silentRecordingExplainsWhyNothingWasRead(testCase)
% Đọc được 0 phím thì dòng trạng thái phải kể lý do loại khung - manh mối
% đầu tiên khi tập demo với loa điện thoại.
app = newApp(testCase);
rng(2026);
app.napBanGhi(0.001 * randn(1, 8000));

testCase.verifyEmpty(app.LblDecoded.Text);
testCase.verifySubstring(app.LblStatus.Text, 'level');
end

function test_statusListsEveryRejectReason(testCase)
% Hai lý do cùng lúc - ca thường gặp nhất với loa điện thoại: khoảng lặng
% cho 'level', âm lệch biên độ 15 dB (ngoài giới hạn +4 dB của Q.24) cho
% 'twist'. Lần đầu viết, dòng trạng thái ném lỗi đúng ở ca này (29/09/2026).
app = newApp(testCase);
[x, ~, ~] = dtmf_generate('5', 'twistDb', 15);
app.napBanGhi([zeros(1, 2000), x, zeros(1, 2000)]);

testCase.verifyEmpty(app.S.lastError);
testCase.verifySubstring(app.LblStatus.Text, 'level');
testCase.verifySubstring(app.LblStatus.Text, 'twist');
end

function test_recordButtonTogglesWithoutDeviceWhenHidden(testCase)
% Chạy ẩn: bấm ghi rồi bấm dừng không mở micro, không ném lỗi, và trả mọi
% nút về như cũ.
app = newApp(testCase);
app.BtnSrcPushed(struct('Source', app.BtnSrcMic));

app.BtnRecordPushed([]);
testCase.verifyEqual(char(app.BtnListen.Enable), 'off');
testCase.verifyEqual(char(app.BtnSrcGen.Enable), 'off');

testCase.verifyWarningFree(@() app.BtnRecordPushed([]));
testCase.verifyEqual(char(app.BtnListen.Enable), 'on');
testCase.verifyEqual(char(app.BtnSrcGen.Enable), 'on');
end

% ------------------------------------------------- nguồn và bước tiếp theo
%
% Thiết kế lại 29/09/2026 vì năm nút của hai quy trình nằm chung một chỗ và
% người dùng không biết khi nào bấm nút nào. Ba luật được ghim ở đây: (1) chỉ
% thẻ của nguồn đang chọn được hiện; (2) nút của bước cần bấm TIẾP THEO được
% tô màu nhấn (đọc qua FontWeight = 'bold'); (3) nút chưa dùng được bị khóa.

function test_sourceTabsShowOnlyTheirControls(testCase)
app = newApp(testCase);

testCase.verifyEqual(char(app.PnlKeypad.Visible), 'on');
testCase.verifyEqual(char(app.PnlMic.Visible), 'off');
testCase.verifyEqual(char(app.BtnSrcGen.FontWeight), 'bold');

app.BtnSrcPushed(struct('Source', app.BtnSrcMic));
testCase.verifyEqual(char(app.PnlKeypad.Visible), 'off');
testCase.verifyEqual(char(app.PnlMic.Visible), 'on');
testCase.verifyEqual(char(app.BtnSrcMic.FontWeight), 'bold');
testCase.verifyEqual(char(app.BtnSrcGen.FontWeight), 'normal');

app.BtnSrcPushed(struct('Source', app.BtnSrcGen));
testCase.verifyEqual(char(app.PnlKeypad.Visible), 'on');
testCase.verifyEqual(char(app.PnlMic.Visible), 'off');
end

function test_switchingSourceClearsTheOldResult(testCase)
% Kết quả của nguồn cũ còn treo trên màn hình sau khi đổi nguồn thì thẻ Kết
% quả nói về một tín hiệu không còn liên quan tới thẻ 02 đang hiện. Chuỗi phím
% thì GIỮ: quay lại nguồn tổng hợp là bấm ① được ngay.
app = appDaSinh(testCase, '0912345', 25);
app.BtnDecodePushed([]);

app.BtnSrcPushed(struct('Source', app.BtnSrcMic));
testCase.verifyEmpty(app.S.y);
testCase.verifyEmpty(app.LblDecoded.Text);

app.BtnSrcPushed(struct('Source', app.BtnSrcGen));
testCase.verifyEqual(app.EfKeys.Value, '0912345');
testCase.verifyEqual(char(app.BtnGen.FontWeight), 'bold');
end

function test_nextStepButtonIsHighlighted(testCase)
% Đi hết một vòng tổng hợp và kiểm nút nào được tô ở mỗi bước.
app = newApp(testCase);

% Ô phím trống: chưa có gì để phát hay giải mã, không nút nào được tô.
testCase.verifyEqual(char(app.BtnGen.Enable), 'off');
testCase.verifyEqual(char(app.BtnDecode.Enable), 'off');
testCase.verifyEqual(char(app.BtnPlay.Enable), 'off');

% Gõ phím (ValueChanging tới TRƯỚC khi Value đổi): bước tiếp theo là ①.
app.EfKeysValueChanging(struct('Value', '59'));
testCase.verifyEqual(char(app.BtnGen.Enable), 'on');
testCase.verifyEqual(char(app.BtnGen.FontWeight), 'bold');
testCase.verifyEqual(char(app.BtnDecode.FontWeight), 'normal');

% Đã phát: bước tiếp theo là ②, và nghe được.
app.EfKeys.Value = '59';
app.BtnGenPushed([]);
testCase.verifyEqual(char(app.BtnGen.FontWeight), 'normal');
testCase.verifyEqual(char(app.BtnDecode.FontWeight), 'bold');
testCase.verifyEqual(char(app.BtnDecode.Enable), 'on');
testCase.verifyEqual(char(app.BtnPlay.Enable), 'on');
testCase.verifySubstring(app.LblStatus.Text, '②');

% Đã giải mã: xong một vòng, không nút nào cần tô.
app.BtnDecodePushed([]);
testCase.verifyEqual(char(app.BtnGen.FontWeight), 'normal');
testCase.verifyEqual(char(app.BtnDecode.FontWeight), 'normal');

% Sửa chuỗi phím sau khi phát: tín hiệu cũ không còn khớp, lại là ①.
app.Btn1Pushed(struct('Source', app.Btn0));
testCase.verifyEqual(char(app.BtnGen.FontWeight), 'bold');
end

function test_methodChangeWithoutSignalKeepsNextStep(testCase)
% Đổi bộ giải mã khi chưa có tín hiệu thì chỉ ghi nhận lựa chọn. Giải mã một
% tín hiệu rỗng sẽ đánh dấu "đã giải mã" và tắt màu nhấn của nút ② sau đó.
app = newApp(testCase);
app.DdMethod.Value = 'fft';
app.DdMethodValueChanged([]);

app.EfKeys.Value = '59';
app.BtnGenPushed([]);
testCase.verifyEqual(char(app.BtnDecode.FontWeight), 'bold');
testCase.verifyEqual(app.S.method, 'fft');
end

function test_sourceCannotChangeWhileMicIsOn(testCase)
% Đổi nguồn là xóa kết quả, mà micro vẫn đang đổ mẫu vào. Kể cả khi callback
% bị gọi thẳng (nút đã khóa), nguồn cũng không được đổi.
app = newApp(testCase);
app.BtnSrcPushed(struct('Source', app.BtnSrcMic));
app.BtnListenPushed([]);

app.BtnSrcPushed(struct('Source', app.BtnSrcGen));
testCase.verifyEqual(char(app.PnlMic.Visible), 'on');

app.BtnListenPushed([]);
end

function test_generateAfterMicReturnsToSyntheticMode(testCase)
% Sau khi dùng micro, bấm "Phát tín hiệu" phải quay về so đúng/sai với chuỗi
% đã phát như bình thường.
app = newApp(testCase);
app.napBanGhi(dtmf_generate('59'));

app.EfKeys.Value = '0912345';
app.SldSNR.Value = 25;
app.BtnGenPushed([]);
app.BtnDecodePushed([]);

testCase.verifyEqual(app.LblSent.Text, '0912345');
testCase.verifySubstring(app.LblStatus.Text, 'Khớp');
end

% ------------------------------------------------------------------- lỗi

function test_unknownKeyIsLoggedNotThrown(testCase)
% Gõ nhầm một chữ cái là chuyện thường ngày. App phải ghi một dòng vào nhật ký
% rồi chạy tiếp, chứ ném lỗi ra giữa buổi demo thì không cứu được.
app = newApp(testCase);
app.EfKeys.Value = '09a2';

testCase.verifyWarningFree(@() app.BtnGenPushed([]));

testCase.verifyEmpty(app.S.x);
testCase.verifyEmpty(app.S.y);
testCase.verifyTrue(any(contains(string(app.TxtLog.Value), 'a')));
end

function test_decodeErrorReachesTheLog(testCase)
% Lỗi từ tầng src/ đi qua S.lastError của dtmf_run rồi phải hiện lên TxtLog.
% Nuốt im lặng thì người dùng chỉ thấy nhãn kết quả trống mà không hiểu vì sao.
app = appDaSinh(testCase, '0912345', 25);
app.S.fs = 'khong phai so';
app.BtnDecodePushed([]);

testCase.verifyNotEmpty(app.S.lastError);
testCase.verifyTrue(any(strlength(string(app.TxtLog.Value)) > 0));
end

function test_emptyKeyStringIsNormalisedToOneByZero(testCase)
% Ô phím trống là trạng thái bình thường (vừa mở app, hoặc vừa xóa trắng),
% không phải lỗi.
%
% uieditfield trả về '' tức 0×0, còn luật CONTRACTS §2 quy định mọi giá trị
% rỗng là 1×0. dtmf_generate nhận cả hai cỡ nên thiếu bước chuẩn hóa thì
% KHÔNG có lỗi nào nổ ra - chuỗi 0×0 chỉ lặng lẽ đi tiếp sang meta.keys rồi
% làm một ca so chuỗi ở đâu đó báo sai. Ghim cỡ ngay tại đây.
app = newApp(testCase);
app.EfKeys.Value = '';

testCase.verifyWarningFree(@() app.BtnGenPushed([]));

testCase.verifyEmpty(app.S.lastError);
testCase.verifyEmpty(app.S.x);
testCase.verifySize(app.S.keys, [1 0]);
end

% -------------------------------------------------------------------- ui_play

function test_playRefusesEmptyAndNonFiniteSignal(testCase)
% NaN/Inf lọt vào sound() thành một tiếng rè rất to qua loa phòng học. Hai
% chốt này phải nằm TRƯỚC lời gọi sound, không phải trong try/catch của nó.
testCase.verifyFalse(ui_play(zeros(1, 0), 8000));
testCase.verifyFalse(ui_play([0 NaN 0.5], 8000));
testCase.verifyFalse(ui_play([0 Inf 0.5], 8000));
end
