function tests = test_decode_goertzel
%TEST_DECODE_GOERTZEL Unit test cho dtmf_decode_goertzel - bộ giải mã đầu tiên chạy thông.
tests = functiontests(localfunctions);
end

function test_decodesCleanSignal(testCase)
% Vòng tròn khép kín: sinh ra rồi đọc lại phải ra đúng chuỗi ban đầu. Đây là
% ca duy nhất kiểm được cả 4 hàm Buổi 1-4 ráp vào nhau có chạy hay không.
[x, ~, m] = dtmf_generate('0912345');
testCase.verifyEqual(dtmf_decode_goertzel(x), m.keys);
end

function test_infoShape(testCase)
% Hợp đồng hình dạng trong CONTRACTS.md. Ba bộ giải mã phải trả y hệt nhau,
% nếu không app/dtmf_run.m và ui_plot_* sẽ phải viết nhánh riêng cho từng bộ.
x = dtmf_generate('0912345');
[~, info] = dtmf_decode_goertzel(x);
n = numel(dtmf_segment(x));

testCase.verifyEqual(size(info.E), [8 n]);
testCase.verifyEqual(size(info.rowIdx), [1 n]);
testCase.verifyEqual(size(info.colIdx), [1 n]);
testCase.verifyEqual(size(info.conf),   [1 n]);
testCase.verifyEqual(size(info.tFrame), [1 n]);
testCase.verifyEqual(size(info.reject), [1 n]);
testCase.verifyTrue(iscellstr(info.reject));
end

function test_tFrameIsFrameCentre(testCase)
% Ghim quyết định (e): tFrame là TÂM khung, KHÔNG phải tStart. Cả ba bộ giải
% mã phải lấy giống nhau, lệch quy ước thì biểu đồ chồng ở Buổi 10 lệch trục
% thời gian mà không ai biết vì mỗi bộ vẫn "tăng ngặt" đúng như đặc tả.
x = dtmf_generate('0912345');
[~, info] = dtmf_decode_goertzel(x);
seg = dtmf_segment(x);

testCase.verifyEqual(info.tFrame, ...
    arrayfun(@(s) (s.tStart + s.tEnd)/2, seg), 'AbsTol', 1e-12);
testCase.verifyEqual(info.tFrame(1), 205/(2*8000), 'AbsTol', 1e-12);
testCase.verifyNotEqual(info.tFrame(1), seg(1).tStart);   % tStart = 0
testCase.verifyTrue(all(diff(info.tFrame) > 0));
end

function test_confInRange(testCase)
% conf phải nằm trong [0, 1] và bằng 0 ĐÚNG ở những khung bị loại - ui_refresh
% chọn khung hiển thị bằng max(info.conf) nên khung bị loại không được thắng.
x = dtmf_addnoise(dtmf_generate('0912345'), 'snrDb', 15);
[~, info] = dtmf_decode_goertzel(x);

testCase.verifyTrue(all(info.conf >= 0 & info.conf <= 1));
testCase.verifyEqual(info.conf == 0, ~strcmp(info.reject, 'none'));
end

function test_energyScaleIsNormalized(testCase)
% Ghim quyết định (a). sum(E(1:7)) phải là TỈ LỆ năng lượng, tức bám quanh 1
% cho khung tone sạch. Sai hằng số chuẩn hóa thì nó lệch đi một thừa số cố
% định - đúng lỗi đã xảy ra ở nhánh FFT, nơi thiếu bù cửa sổ kéo nó xuống
% 0.63 và bộ giải mã loại sạch 100% số khung mà vẫn "chạy bình thường".
x = dtmf_generate('0912345');
[~, info] = dtmf_decode_goertzel(x);
rho = sum(info.E(1:7, :), 1);
acc = strcmp(info.reject, 'none');

testCase.verifyGreaterThan(max(rho), 0.90);     % khung tone sạch gần 1
testCase.verifyLessThanOrEqual(max(rho), 1.05); % không vượt quá 1 đáng kể
testCase.verifyGreaterThanOrEqual(min(rho(acc)), 0.70);
end

function test_amplitudeInvariance(testCase)
% Hệ quả của chuẩn hóa: vặn nhỏ âm lượng 100 lần vẫn ra đúng chuỗi đó. Nếu ai
% bỏ bước chia cho năng lượng khung, ca này đỏ ngay.
x = dtmf_generate('0912345');
testCase.verifyEqual(dtmf_decode_goertzel(0.01*x), dtmf_decode_goertzel(x));
end

function test_harmonicBinFollowsPeak(testCase)
% Ghim quyết định (b): bin hài bậc 2 bám theo ĐỈNH CỦA TỪNG KHUNG chứ không
% phải một bin cố định. Tín hiệu dưới là 770 Hz + 1336 Hz (phím '5') cộng
% năng lượng tại đúng hài bậc 2 của 770 Hz, tức bin 2*20 = 40 (1561 Hz).
%
% Bám theo đỉnh thì nhìn đúng bin 40, thấy hài, loại khung với nhãn
% 'harmonic'. Lấy bin cố định 2*k(1) = 36 (1405 Hz) thì không thấy gì, khung
% qua sạch và hàm trả về '5' - một phím KHÔNG hề được bấm. Đây là cổng chống
% talk-off, hỏng ở đây nghĩa là tiếng nói bị đọc thành phím bấm.
fs = 8000; frameN = 205;
t = (0:1024) / fs;
x = sin(2*pi*770*t) + 0.5*sin(2*pi*1336*t) + 0.4*sin(2*pi*(40*fs/frameN)*t);

[keys, info] = dtmf_decode_goertzel(x);
testCase.verifyEmpty(keys);
testCase.verifyTrue(all(strcmp(info.reject, 'harmonic')));
end

function test_silenceDecodesToNothing(testCase)
% Im lặng hoàn toàn: không ký tự nào, và mọi khung mang nhãn 'level'. Khung
% toàn 0 cho 0/0 = NaN nếu chia thẳng, khi đó mọi so sánh thành false và
% khung rác lọt qua với nhãn 'none' - ca này bắt đúng chỗ đó.
%
% verifyTrue(isfinite) không thừa: dtmf_decide có chốt chặn isfinite riêng
% nên nhãn vẫn ra 'level' dù info.E đầy NaN, tức nhãn KHÔNG bảo vệ được E.
% Mà Buổi 8 ui_plot_bars vẽ chính info.E - cột NaN thì không hiện lên.
[keys, info] = dtmf_decode_goertzel(zeros(1, 4000));

testCase.verifyEmpty(keys);
testCase.verifyClass(keys, 'char');
testCase.verifyTrue(all(strcmp(info.reject, 'level')));
testCase.verifyTrue(all(info.rowIdx == 0));
testCase.verifyTrue(all(isfinite(info.E(:))));
end

function test_emptyWhenShorterThanFrame(testCase)
% y ngắn hơn một khung: nFrame = 0. Phải trả rỗng ĐÚNG CỠ 1×0 / 8×0 chứ không
% phải 0×0, và không được ném lỗi - Buổi 8 GUI gọi với tín hiệu bất kỳ.
% Kiểm rỗng bằng verifyEmpty chứ không verifyEqual(keys, ''): '' là 0×0 còn
% keys là 1×0, hai cỡ đó strcmp với nhau ra false.
[keys, info] = testCase.verifyWarningFree(@() decodeTwo(zeros(1, 100)));

testCase.verifyEmpty(keys);
testCase.verifyClass(keys, 'char');
testCase.verifyEqual(size(info.E), [8 0]);
testCase.verifyEqual(size(info.rowIdx), [1 0]);
testCase.verifyEqual(size(info.reject), [1 0]);
testCase.verifyTrue(iscell(info.reject));
end

function varargout = decodeTwo(y)
%DECODETWO Gói cả hai đầu ra để verifyWarningFree lấy được cả keys lẫn info.
[varargout{1}, varargout{2}] = dtmf_decode_goertzel(y);
end
