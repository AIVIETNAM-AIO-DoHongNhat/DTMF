function tests = test_ui_smoke
%TEST_UI_SMOKE Kiểm tầng vẽ app/ui chạy được headless và vẽ ĐÚNG dữ liệu.
%
% Chạy trong matlab -batch nên mọi uifigure phải 'Visible','off' và phải được
% xóa bằng onCleanup: figure sót lại làm ca sau đếm nhầm số cửa sổ.
%
tests = functiontests(localfunctions);
end

function ax = newAxes(testCase)
% Dựng một uiaxes ẩn, tự hủy khi ca test kết thúc.
f = uifigure('Visible', 'off');
testCase.addTeardown(@() delete(f));
ax = uiaxes(f);
end

function app = fakeApp(testCase, S)
% Đứng thay DTMFApp (chưa có tới Buổi 9). Hợp lệ vì ui_refresh CHỈ đụng sáu
% thành phần này - xem CONTRACTS §8; một struct chứa đúng sáu handle đó thỏa
% mãn hợp đồng y hệt một classdef.
f = uifigure('Visible', 'off');
testCase.addTeardown(@() delete(f));
app = struct('AxWave', uiaxes(f), 'AxSpec', uiaxes(f), 'AxBars', uiaxes(f), ...
             'LblDecoded', uilabel(f), 'TxtLog', uitextarea(f), 'S', S);
end

function S = ranState(method)
% Trạng thái đã chạy dtmf_run - đúng thứ mà callback truyền vào ui_refresh.
[x, ~, m] = dtmf_generate('59');
S = dtmf_run(struct('y', x, 'fs', 8000, 'method', method));
S.meta = m;
end

function E = sampleFrame()
% Khung thật của phím '5' - dùng chung cho nhiều ca.
[~, info] = dtmf_decode_goertzel(dtmf_generate('5'));
[~, i] = max(info.conf);
E = info.E(:, i);
end

% ---------------------------------------------------------------- ui_plot_bars

function test_barOrderMatchesInfoE(testCase)
% GHIM thứ tự 8 cột.
%
% categorical(lab) TỰ SẮP XẾP hạng mục theo chữ cái, cho ra
% 1209 1336 1477 2f 697 770 852 941 - mỗi cột đứng dưới SAI NHÃN mà hình vẫn
% có 8 cột và hai cột cao, không một chữ cảnh báo. Phải là categorical(lab,lab).
ax = newAxes(testCase);
E  = sampleFrame();
ui_plot_bars(ax, E, 0.196);

b = findobj(ax, 'Type', 'bar');
testCase.verifyEqual(categories(b.XData)', ...
    {'697', '770', '852', '941', '1209', '1336', '1477', '2f'});

% Và chiều cao phải khớp TỪNG cột, không chỉ đúng tập hợp giá trị.
testCase.verifyEqual(b.YData(:), E(:), 'AbsTol', 1e-12);
end

function test_highlightsBarsAboveThreshold(testCase)
% Hai cột vượt ngưỡng chính là hàng và cột mà dtmf_decide chọn - đó là thứ làm
% hình này tự giải thích được quyết định.
ax = newAxes(testCase);
E  = sampleFrame();
thr = 0.5 * min(max(E(1:4)), max(E(5:7)));
ui_plot_bars(ax, E, thr);

b = findobj(ax, 'Type', 'bar');
cam = ismember(b.CData, [0.90 0.45 0.13], 'rows');
testCase.verifyEqual(nnz(cam), 2);
testCase.verifyEqual(find(cam)', find(E(:)' > thr));
end

function test_thresholdLineDrawn(testCase)
% Thiếu đường ngưỡng thì hình mất hẳn phần "vì sao", chỉ còn 8 cột trơ trọi.
ax = newAxes(testCase);
ui_plot_bars(ax, sampleFrame(), 0.196);

ln = findobj(ax, 'Type', 'constantline');
testCase.verifyNotEmpty(ln);
testCase.verifyEqual(ln(1).Value, 0.196, 'AbsTol', 1e-12);
end

function test_emptyEClearsAxes(testCase)
% nFrame = 0 cho iSel = 0, ui_refresh truyền E rỗng. Phải xóa trục, không vẽ
% rác và không ném lỗi - xem CONTRACTS §6(h).
ax = newAxes(testCase);
ui_plot_bars(ax, sampleFrame(), 0.196);       % vẽ trước cho trục có nội dung
testCase.verifyNotEmpty(ax.Children);

ui_plot_bars(ax, [], 0);
testCase.verifyEmpty(ax.Children);
end

function test_silentFrameKeepsValidYLim(testCase)
% Khung im lặng cho E toàn 0 và thr = 0. ylim([0 0]) là lỗi MATLAB, nên phải
% có nhánh chặn; thiếu nó thì trục thanh làm sập cả ui_refresh.
ax = newAxes(testCase);
testCase.verifyWarningFree(@() ui_plot_bars(ax, zeros(8, 1), 0));
testCase.verifyGreaterThan(ax.YLim(2), ax.YLim(1));
end

function test_acceptsRowOrColumnE(testCase)
% info.E(:,i) là cột, nhưng hàm nhận cả 1×8 theo đúng help. Quên E = E(:)'
% thì bar() vẽ 8 nhóm mỗi nhóm 1 cột thay vì 8 cột.
axC = newAxes(testCase);
axR = newAxes(testCase);
E = sampleFrame();
ui_plot_bars(axC, E,  0.196);
ui_plot_bars(axR, E', 0.196);

bC = findobj(axC, 'Type', 'bar');
bR = findobj(axR, 'Type', 'bar');
testCase.verifyEqual(numel(bC), 1);
testCase.verifyEqual(bR.YData, bC.YData, 'AbsTol', 1e-12);
end

function test_barsRejectWrongSize(testCase)
% E không đủ 8 phần tử là gọi sai. Không chốt thì bar() ném
% 'X must be same length as Y' - thông báo không chỉ ra được lỗi của ai, mà
% ui_refresh lại ghi nguyên văn nó vào nhật ký cho người dùng đọc.
ax = newAxes(testCase);
testCase.verifyError(@() ui_plot_bars(ax, [1; 2; 3], 0.2), 'ui_plot_bars:badSize');
testCase.verifyError(@() ui_plot_bars(ax, ones(1, 9), 0.2), 'ui_plot_bars:badSize');
end

function test_doesNotPopWindows(testCase)
% Hàm vẽ KHÔNG được gọi figure(): một cửa sổ bật lên giữa buổi demo là hỏng,
% và trong matlab -batch thì nó làm treo phiên chạy.
n0 = numel(findall(groot, 'Type', 'figure'));
ax = newAxes(testCase);
ui_plot_bars(ax, sampleFrame(), 0.196);
testCase.verifyEqual(numel(findall(groot, 'Type', 'figure')), n0 + 1);
end

% ---------------------------------------------------------------- ui_plot_wave

function test_waveDrawsTheSignalItself(testCase)
% Đường sóng phải là ĐÚNG y và đúng trục thời gian, không phải một bản rút gọn.
ax = newAxes(testCase);
[x, ~, m] = dtmf_generate('59');
ui_plot_wave(ax, x, 8000, m);

ln = findobj(ax, 'Type', 'line');
testCase.verifyNumElements(ln, 1);
testCase.verifyEqual(ln.YData, x, 'AbsTol', 1e-12);
testCase.verifyEqual(ln.XData, (0:numel(x)-1)/8000, 'AbsTol', 1e-12);
end

function test_waveShadesEachToneRegion(testCase)
% Một vùng tô nền cho MỖI phím, đúng mốc onsets/offsets của dtmf_generate.
ax = newAxes(testCase);
[x, ~, m] = dtmf_generate('59');
ui_plot_wave(ax, x, 8000, m);

pa = findobj(ax, 'Type', 'patch');
testCase.verifyNumElements(pa, numel(m.keys));

% findobj trả về theo thứ tự ngược với thứ tự vẽ.
moc = sort(arrayfun(@(h) min(h.XData), pa));
testCase.verifyEqual(moc(:)', sort(m.onsets(:))', 'AbsTol', 1e-12);

% Kiểm cả mốc KẾT THÚC: chỉ so mốc bắt đầu thì một vùng rộng sai vẫn lọt.
het = sort(arrayfun(@(h) max(h.XData), pa));
testCase.verifyEqual(het(:)', sort(m.offsets(:))', 'AbsTol', 1e-12);

% Và mỗi vùng phải là HÌNH CHỮ NHẬT đủ bốn góc, cao hết khung nhìn.
%
% Chỉ so min/max của XData thì không đủ: đảo thứ tự đỉnh thành [x1 x1 x2 x2]
% cho ra một dải chéo suy biến chỉ có hai góc phân biệt, mà min/max vẫn đúng
% y hệt. Lỗ hổng này do kiểm thử đột biến tìm ra.
for h = pa(:)'
    goc = unique([h.XData(:) h.YData(:)], 'rows');
    testCase.verifyEqual(size(goc, 1), 4, 'Vùng tô nền không phải hình chữ nhật.');
    testCase.verifyEqual([min(h.YData) max(h.YData)], ax.YLim, 'AbsTol', 1e-12);
end
end

function test_waveLabelsEachKey(testCase)
% Nhãn phím là thứ nối hình với chuỗi người dùng gõ; thiếu nó thì hình chỉ còn
% là một dải sóng không đọc được.
ax = newAxes(testCase);
[x, ~, m] = dtmf_generate('5*9');
ui_plot_wave(ax, x, 8000, m);

tx = findobj(ax, 'Type', 'text');
testCase.verifyEqual(sort(string({tx.String})), sort(string(num2cell(m.keys))));
end

function test_waveWorksWithoutMeta(testCase)
% meta = [] là trạng thái bình thường (mới mở app, hoặc nạp wav lạ), KHÔNG
% phải lỗi. Vẫn phải có đường sóng, và không được có vùng tô nền nào.
ax = newAxes(testCase);
x = dtmf_generate('59');
testCase.verifyWarningFree(@() ui_plot_wave(ax, x, 8000, []));

testCase.verifyNumElements(findobj(ax, 'Type', 'line'), 1);
testCase.verifyEmpty(findobj(ax, 'Type', 'patch'));
end

function test_waveWithPartialMetaDoesNotThrow(testCase)
% meta thiếu trường, hoặc ba trường lệch độ dài: vẫn phải vẽ được. Một lỗi
% "index exceeds" giữa buổi demo là thứ không cứu được.
ax = newAxes(testCase);
x = dtmf_generate('59');
testCase.verifyWarningFree(@() ui_plot_wave(ax, x, 8000, struct('onsets', 0)));

[~, ~, m] = dtmf_generate('59');
m.keys = m.keys(1);                          % lệch: 2 mốc nhưng 1 phím
testCase.verifyWarningFree(@() ui_plot_wave(ax, x, 8000, m));
testCase.verifyNumElements(findobj(ax, 'Type', 'patch'), 1);
end

function test_waveHandlesEmptyAndSilentSignal(testCase)
% y rỗng: xóa trục. y toàn 0: a = 0 nên ylim([0 0]) là lỗi, phải có nhánh chặn.
axE = newAxes(testCase);
ui_plot_wave(axE, zeros(1, 0), 8000, []);
testCase.verifyEmpty(findobj(axE, 'Type', 'line'));

axS = newAxes(testCase);
testCase.verifyWarningFree(@() ui_plot_wave(axS, zeros(1, 800), 8000, []));
testCase.verifyGreaterThan(axS.YLim(2), axS.YLim(1));
testCase.verifyGreaterThan(axS.XLim(2), axS.XLim(1));
end

% ---------------------------------------------------------------- ui_plot_spec

function test_specUsesSameParametersAsFftDecoder(testCase)
% GHIM tham số cửa sổ. Đây là bẫy chính của hàm này: lệch cửa sổ hay chồng lấp
% thì hình phổ KHÔNG còn là cái dtmf_decode_fft nhìn thấy, mà hình vẫn đẹp và
% vẫn thấy hai vạch sáng - sai mà không có dấu hiệu gì.
ax = newAxes(testCase);
y  = dtmf_generate('59');
ui_plot_spec(ax, y, 8000);

[sMong, fMong, tMong] = spectrogram(y, hamming(256), 128, 256, 8000);
im = findobj(ax, 'Type', 'image');
testCase.verifyNumElements(im, 1);
testCase.verifyEqual(im.XData(:), tMong(:), 'AbsTol', 1e-12);
testCase.verifyEqual(im.YData(:), fMong(:), 'AbsTol', 1e-12);

% Và phải so cả GIÁ TRỊ ảnh, không chỉ hai trục.
%
% Lỗ hổng do kiểm thử đột biến tìm ra: đổi hamming(256) thành cửa sổ chữ nhật
% ones(256,1) không làm đổi trục thời gian lẫn trục tần số - chúng chỉ phụ
% thuộc độ dài, chồng lấp và NFFT. Chỉ có CData mới phân biệt được HÌNH DẠNG
% cửa sổ, mà hình dạng mới là thứ phải khớp dtmf_decode_fft.
testCase.verifyEqual(im.CData, 10*log10(abs(sMong).^2 + eps), 'RelTol', 1e-12);
end

function test_specAxisIsNotFlipped(testCase)
% imagesc mặc định lật trục y. Thiếu axis(ax,'xy') thì 0 Hz nằm trên đỉnh và
% hình đọc ngược - mà nhìn vẫn "có vẻ đúng" vì hai vạch DTMF vẫn ở đó.
ax = newAxes(testCase);
ui_plot_spec(ax, dtmf_generate('59'), 8000);
testCase.verifyEqual(ax.YDir, 'normal');
end

function test_specMarksSevenStandardFrequencies(testCase)
% Bảy đường phải trùng đúng bảng tần số, không phải bảy số chép tay.
ax = newAxes(testCase);
ui_plot_spec(ax, dtmf_generate('59'), 8000);

T  = dtmf_table();
ln = findobj(ax, 'Type', 'constantline');
testCase.verifyEqual(sort([ln.Value]), sort([T.rowHz T.colHz]), 'AbsTol', 1e-12);
end

function test_specYLimCoversSecondHarmonic(testCase)
% [0 3000] bao trọn hài bậc 2 của nhóm cột (2418-2954 Hz), tức đúng dải mà
% thanh thứ 8 của ui_plot_bars đang đo.
ax = newAxes(testCase);
ui_plot_spec(ax, dtmf_generate('59'), 8000);
testCase.verifyEqual(ax.YLim, [0 3000]);
end

function test_specShortSignalDoesNotThrow(testCase)
% Ngắn hơn một cửa sổ thì spectrogram ném lỗi. Giao diện lúc mới mở và lúc
% người dùng gõ một phím rồi xóa đều rơi vào đây.
ax = newAxes(testCase);
testCase.verifyWarningFree(@() ui_plot_spec(ax, zeros(1, 100), 8000));
testCase.verifyEmpty(findobj(ax, 'Type', 'image'));

testCase.verifyWarningFree(@() ui_plot_spec(ax, zeros(1, 0), 8000));
end

function test_specSilentSignalDoesNotBlowUpColourScale(testCase)
% Tín hiệu toàn 0 cho log10(0) = -Inf. Thiếu "+ eps" thì thang màu bị kéo tới
% -Inf và cả hình thành một màu duy nhất.
ax = newAxes(testCase);
testCase.verifyWarningFree(@() ui_plot_spec(ax, zeros(1, 2048), 8000));

im = findobj(ax, 'Type', 'image');
testCase.verifyTrue(all(isfinite(im.CData(:))));
end

% ---------------------------------------------------------------- ui_refresh

function test_refreshDrawsAllThreeAxes(testCase)
% Một lần gọi phải làm đầy cả ba trục. Quên một lời gọi thì trục đó trống trơn
% mà không có lỗi nào - trên màn hình chỉ là một ô trắng khó hiểu.
app = fakeApp(testCase, ranState('fft'));
ui_refresh(app);

testCase.verifyNotEmpty(findobj(app.AxWave, 'Type', 'line'));
testCase.verifyNotEmpty(findobj(app.AxSpec, 'Type', 'image'));
testCase.verifyNotEmpty(findobj(app.AxBars, 'Type', 'bar'));
end

function test_refreshShowsDecodedKeys(testCase)
% Nhãn kết quả là thứ người chấm nhìn đầu tiên trong buổi demo.
app = fakeApp(testCase, ranState('goertzel'));
ui_refresh(app);
testCase.verifyEqual(app.LblDecoded.Text, '59');
end

function test_refreshLogsLastError(testCase)
% Lỗi từ dtmf_run phải hiện ra cho người dùng, không được nuốt im lặng.
S = ranState('fft');
S.lastError = 'method khong hop le: abc';
app = fakeApp(testCase, S);
ui_refresh(app);

testCase.verifyTrue(any(contains(string(app.TxtLog.Value), 'khong hop le')));
end

function test_refreshLeavesLogAloneWhenNoError(testCase)
% Chạy thành công thì KHÔNG được đụng vào nhật ký.
%
% Bỏ chốt ~isempty(S.lastError) thì mỗi lần vẽ lại nối thêm một dòng RỖNG; sau
% vài chục lần bấm, ô nhật ký đầy dòng trắng và các thông báo thật bị đẩy khuất.
% Lỗ hổng này do kiểm thử đột biến tìm ra.
app = fakeApp(testCase, ranState('fft'));
app.TxtLog.Value = {'dong cu'};
ui_refresh(app);

testCase.verifyEqual(string(app.TxtLog.Value(:))', "dong cu");
end

function test_refreshAppendsWithoutErasingLog(testCase)
% Nối vào CUỐI, không ghi đè: người dùng cần cả chuỗi sự kiện chứ không chỉ
% thông báo gần nhất.
S = ranState('fft');
S.lastError = 'loi moi';
app = fakeApp(testCase, S);
app.TxtLog.Value = {'dong cu 1'; 'dong cu 2'};
ui_refresh(app);

v = string(app.TxtLog.Value);
testCase.verifyEqual(v(1), "dong cu 1");
testCase.verifyEqual(v(end), "loi moi");
end

function test_refreshDoesNotKeepDefaultBlankLine(testCase)
% uitextarea mới dựng có Value = {''}, không phải {}. Giữ nguyên nó thì mọi
% thông báo đều bị đẩy xuống sau một dòng trắng, mãi mãi.
S = ranState('fft');
S.lastError = 'loi dau tien';
app = fakeApp(testCase, S);
ui_refresh(app);

testCase.verifyEqual(string(app.TxtLog.Value(:))', "loi dau tien");
end

function test_refreshClearsBarsWhenNoFrame(testCase)
% iSel = 0 (tín hiệu rỗng, chưa bấm gì): trục thanh phải trắng, không vẽ rác.
S = dtmf_run(struct('y', zeros(1, 0), 'fs', 8000, 'method', 'fft'));
app = fakeApp(testCase, S);
testCase.verifyWarningFree(@() ui_refresh(app));
testCase.verifyEmpty(findobj(app.AxBars, 'Type', 'bar'));
end

function test_refreshSurvivesEmptyState(testCase)
% S trống hoàn toàn - trạng thái của giao diện ngay khi vừa mở, trước lần
% dtmf_run đầu tiên. Không được ném lỗi.
app = fakeApp(testCase, struct());
testCase.verifyWarningFree(@() ui_refresh(app));
end

function test_refreshKeepsGoingWhenOnePlotFails(testCase)
% GHIM luật mỗi hàm vẽ một try/catch RIÊNG.
%
% Gộp chung một try/catch thì hỏng trục thanh kéo theo mất luôn dạng sóng và
% phổ đồ - mất hai phần ba thông tin trên màn hình chỉ vì hỏng một phần ba.
app = fakeApp(testCase, ranState('fft'));
delete(app.AxBars);                       % trục hỏng: mọi lệnh vẽ lên nó đều lỗi

testCase.verifyWarningFree(@() ui_refresh(app));
testCase.verifyNotEmpty(findobj(app.AxWave, 'Type', 'line'));
testCase.verifyNotEmpty(findobj(app.AxSpec, 'Type', 'image'));
testCase.verifyNotEmpty(app.TxtLog.Value);
testCase.verifyEqual(app.LblDecoded.Text, '59');
end

function test_refreshDoesNotComputeAnything(testCase)
% Tầng UI không được tính toán - §6(h). Nếu ui_refresh tự tính iSel hay thr
% thì nó sẽ vẽ được ngay cả khi dtmf_run chưa dọn hai trường đó; ở đây chúng
% bị cố tình đặt sai và trục thanh phải im lặng làm theo, không "sửa hộ".
S = ranState('fft');
S.iSel = 0;
app = fakeApp(testCase, S);
ui_refresh(app);

testCase.verifyEmpty(findobj(app.AxBars, 'Type', 'bar'));
end
