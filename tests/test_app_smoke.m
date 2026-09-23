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
                   'BtnPlay', 'LblDecoded', 'TxtLog'}];
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
