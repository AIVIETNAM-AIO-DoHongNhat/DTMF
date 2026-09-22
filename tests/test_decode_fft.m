function tests = test_decode_fft
%TEST_DECODE_FFT Unit test cho dtmf_decode_fft - bộ giải mã đối chứng của Goertzel.
tests = functiontests(localfunctions);
end

function test_decodesCleanSignal(testCase)
% Vòng tròn khép kín cho nhánh FFT: sinh ra rồi đọc lại phải ra đúng chuỗi.
[x, ~, m] = dtmf_generate('0912345');
testCase.verifyEqual(dtmf_decode_fft(x), m.keys);
end

function test_matchesGoertzel(testCase)
% CA QUAN TRỌNG NHẤT CẢ FILE. Đây là thứ CHỨNG MINH "ba bộ giải mã dùng chung
% luật quyết định" là sự thật chứ không phải khẩu hiệu: hai bộ chia khung khác
% nhau (205 không chồng lấp / 256 chồng lấp 50%), đo phổ bằng hai thuật toán
% khác nhau, mà phải ra CÙNG MỘT chuỗi.
%
% Ai đó lỡ đổi một ngưỡng trong dtmf_decide thì cả hai cùng lệch nên ca này
% vẫn xanh - đó là việc của test_decide. Ca này bắt chuyện khác: một trong hai
% bộ giải mã tự ý đi chệch khỏi luật chung.
for s = {'0912345', '159', '*0#', '4826', '12345699'}
    x = dtmf_generate(s{1});
    testCase.verifyEqual(dtmf_decode_fft(x), dtmf_decode_goertzel(x), ...
        sprintf('chuoi "%s"', s{1}));
    testCase.verifyEqual(dtmf_decode_fft(x), s{1}, sprintf('chuoi "%s"', s{1}));
end

% Có nhiễu thì hai bộ KHÔNG bắt buộc giống nhau từng khung - khung của chúng
% phủ những đoạn tín hiệu khác nhau nên gặp những mẫu nhiễu khác nhau. Ở 20 dB
% cả hai còn rất xa vách 6 dB, nên khẳng định cả hai bằng CHUỖI THẬT.
rng(2026);
y = dtmf_addnoise(dtmf_generate('0912345'), 'snrDb', 20);
testCase.verifyEqual(dtmf_decode_fft(y), '0912345');
testCase.verifyEqual(dtmf_decode_goertzel(y), '0912345');
end

function test_infoShape(testCase)
% Hợp đồng hình dạng trong CONTRACTS.md, y hệt Goertzel. Ba bộ giải mã phải
% trả cùng cỡ, nếu không app/dtmf_run.m và ui_plot_* phải viết nhánh riêng.
x = dtmf_generate('0912345');
[~, info] = dtmf_decode_fft(x);
n = numel(dtmf_segment(x, 'frameN', 256, 'hop', 128));

testCase.verifyEqual(size(info.E), [8 n]);
testCase.verifyEqual(size(info.rowIdx), [1 n]);
testCase.verifyEqual(size(info.colIdx), [1 n]);
testCase.verifyEqual(size(info.conf),   [1 n]);
testCase.verifyEqual(size(info.tFrame), [1 n]);
testCase.verifyEqual(size(info.reject), [1 n]);
testCase.verifyTrue(iscellstr(info.reject));
end

function test_tFrameIsFrameCentre(testCase)
% Ghim quyết định (e). Khung ở đây dài 256 chứ không phải 205, nên lấy nhầm
% tStart làm lệch 256/(2*8000) = 16 ms so với quy ước, và khác Goertzel
% 3.1875 ms - đủ để hai đường trên biểu đồ chồng ở Buổi 10 lệch nhau mà mỗi
% đường nhìn riêng vẫn "tăng ngặt" đúng đặc tả.
x = dtmf_generate('0912345');
[~, info] = dtmf_decode_fft(x);
seg = dtmf_segment(x, 'frameN', 256, 'hop', 128);

testCase.verifyEqual(info.tFrame, ...
    arrayfun(@(s) (s.tStart + s.tEnd)/2, seg), 'AbsTol', 1e-12);
testCase.verifyEqual(info.tFrame(1), 256/(2*8000), 'AbsTol', 1e-12);
testCase.verifyNotEqual(info.tFrame(1), seg(1).tStart);   % tStart = 0
testCase.verifyTrue(all(diff(info.tFrame) > 0));
end

function test_confInRange(testCase)
% conf thuộc [0,1] và bằng 0 ĐÚNG ở khung bị loại - ui_refresh chọn khung hiển
% thị bằng max(info.conf) nên khung bị loại không được thắng.
x = dtmf_addnoise(dtmf_generate('0912345'), 'snrDb', 15);
[~, info] = dtmf_decode_fft(x);

testCase.verifyTrue(all(info.conf >= 0 & info.conf <= 1));
testCase.verifyEqual(info.conf == 0, ~strcmp(info.reject, 'none'));
end

function test_windowGainCompensated(testCase)
% GHIM HỆ SỐ BÙ CỬA SỔ cg = sum(w)^2/(frameN*sum(w.^2)) = 0.7317.
%
% Nhân cửa sổ làm tụt biên độ vạch phổ NHIỀU HƠN làm tụt năng lượng khung, nên
% thiếu cg thì mọi rho bị nhân đúng 0.7317: đỉnh 0.9470 tụt còn 0.6929 và
% khung được nhận thấp nhất 0.7254 tụt còn 0.5308 - cả hai đều dưới ngưỡng
% 0.70. Hậu quả KHÔNG phải "kém chính xác" mà là hỏng hẳn: loại 100% số khung,
% trả chuỗi rỗng ở mọi mức SNR, và hàm vẫn chạy êm không một cảnh báo.
%
% Ngưỡng 0.90 dưới đây nằm giữa 0.9470 (có cg) và 0.6929 (thiếu cg) nên nó
% tách được đúng hai trường hợp đó.
x = dtmf_generate('0912345');
[~, info] = dtmf_decode_fft(x);
rho = sum(info.E(1:7, :), 1);
acc = strcmp(info.reject, 'none');

testCase.verifyGreaterThan(max(rho), 0.90);
testCase.verifyLessThanOrEqual(max(rho), 1.05);
testCase.verifyGreaterThanOrEqual(min(rho(acc)), 0.70);
end

function test_amplitudeInvariance(testCase)
% Hệ quả của chuẩn hóa: vặn nhỏ âm lượng 100 lần vẫn ra đúng chuỗi đó.
x = dtmf_generate('0912345');
testCase.verifyEqual(dtmf_decode_fft(0.01*x), dtmf_decode_fft(x));
end

function test_harmonicBinFollowsPeak(testCase)
% Ghim quyết định (b) cho lưới bin của N = 256 - KHÔNG chép số từ nhánh
% Goertzel được, vì ở đó bin hài của 770 Hz là 40 còn ở đây là 50.
%
% Tín hiệu: 770 Hz + 1336 Hz (phím '5') cộng năng lượng tại đúng hài bậc 2 của
% 770 Hz, tức bin 2*25 = 50 (1562.5 Hz). Bám theo đỉnh thì nhìn đúng bin 50,
% đo được E(8) = 0.1115 > ngưỡng 0.0812 và loại cả 15 khung. Lấy bin cố định
% 2*k(1) = 44 (1375 Hz) thì chỉ thấy 0.0107, khung qua sạch và hàm trả về '5'
% - một phím KHÔNG hề được bấm. Đây là cổng chống talk-off.
%
% Biên độ 0.4 chọn bằng cách ĐO chứ không suy từ công thức: dưới 0.3 thì cả
% hai cách đều cho '5', từ 0.5 trở lên thì năng lượng hài kéo rho xuống dưới
% 0.70 nên cả hai cùng loại với nhãn 'level' và ca test mất ý nghĩa.
fs = 8000; frameN = 256;
t = (0:2047) / fs;
x = sin(2*pi*770*t) + 0.5*sin(2*pi*1336*t) + 0.4*sin(2*pi*(50*fs/frameN)*t);

[keys, info] = dtmf_decode_fft(x);
testCase.verifyEmpty(keys);
testCase.verifyTrue(all(strcmp(info.reject, 'harmonic')));
end

function test_everyFrameGridAlignment(testCase)
% Quét CẠN mọi cách khung rơi lên tone, không phải thử vài chuỗi rồi hy vọng.
%
% Mỗi phím chiếm 1200 mẫu, khung nhảy từng hop = 128. Độ lệch tương đối của
% phím thứ i là mod((i-1)*1200, 128); vì mod(1200,128) = 48 và gcd(48,128) =
% 16 nên nó chạy hết 128/16 = 8 giá trị rồi lặp. Chuỗi 16 phím dưới đây phủ
% mỗi cách căn lề đúng hai lần.
%
% SỐ 8 NÀY GẮN VỚI hop = 128, KHÔNG phải 41 như nhánh Goertzel (hop = 205).
% Khẳng định gcd ở đây để ai đổi hop hay toneMs thì lập luận vỡ ra thấy ngay
% chứ không âm thầm biến ca này thành phép thử một vài trường hợp.
testCase.verifyEqual(mod(1200, 128), 48);
testCase.verifyEqual(gcd(48, 128), 16);

s = '7977506822135400';   % có sẵn ba cặp phím lặp: '77', '22', '00'
testCase.verifyEqual(dtmf_decode_fft(dtmf_generate(s)), s);
end

function test_silenceDecodesToNothing(testCase)
% Im lặng hoàn toàn: không ký tự nào, mọi khung mang nhãn 'level'.
%
% verifyTrue(isfinite) không thừa: bỏ chốt en > 0 thì info.E đầy NaN, nhưng
% dtmf_decide có chốt isfinite riêng nên nhãn VẪN ra 'level' - tức nhãn không
% bảo vệ được E. Mà Buổi 8 ui_plot_bars vẽ chính info.E, cột NaN không hiện.
[keys, info] = dtmf_decode_fft(zeros(1, 4000));

testCase.verifyEmpty(keys);
testCase.verifyClass(keys, 'char');
testCase.verifyTrue(all(strcmp(info.reject, 'level')));
testCase.verifyTrue(all(info.rowIdx == 0));
testCase.verifyTrue(all(isfinite(info.E(:))));
end

function test_emptyWhenShorterThanFrame(testCase)
% y ngắn hơn một khung: nFrame = 0. Phải trả rỗng ĐÚNG CỠ 1×0 / 8×0 chứ không
% phải 0×0, và không được ném lỗi - Buổi 8 GUI gọi với tín hiệu bất kỳ.
% Ngưỡng ở đây là 256 chứ không phải 205: y dài 200 mẫu lọt qua nhánh Goertzel
% nhưng rỗng ở nhánh này, nên hai bộ KHÔNG chia sẻ được ca test này.
[keys, info] = testCase.verifyWarningFree(@() decodeTwo(zeros(1, 200)));

testCase.verifyEmpty(keys);
testCase.verifyClass(keys, 'char');
testCase.verifyEqual(size(info.E), [8 0]);
testCase.verifyEqual(size(info.rowIdx), [1 0]);
testCase.verifyEqual(size(info.reject), [1 0]);
testCase.verifyTrue(iscell(info.reject));
end

function varargout = decodeTwo(y)
%DECODETWO Gói cả hai đầu ra để verifyWarningFree lấy được cả keys lẫn info.
[varargout{1}, varargout{2}] = dtmf_decode_fft(y);
end
