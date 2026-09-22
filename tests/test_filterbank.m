function tests = test_filterbank
%TEST_FILTERBANK Unit test cho design_bpf_bank + dtmf_decode_filterbank.
tests = functiontests(localfunctions);
end

% =====================================================================
% Nhóm 1 - thiết kế bộ lọc
% =====================================================================

function test_unitGainAtCentre(testCase)
% |H(f0)| = 1 cho cả 14 bộ. Đây là thứ làm năng lượng đầu ra của 14 bộ CÙNG
% MỘT THANG; sai một bộ thì bin đó luôn thắng hoặc luôn thua trong argmax.
%
% freqz(b, a, f, fs) với f VÔ HƯỚNG bị hiểu là SỐ ĐIỂM chứ không phải tần số -
% phải truyền vector. Đây là bẫy đã làm hỏng lần chạy thử đầu tiên.
bank = design_bpf_bank();
for j = 1:numel(bank)
    H = freqz(bank(j).b, bank(j).a, [bank(j).f bank(j).f], 8000);
    testCase.verifyEqual(abs(H(1)), 1, 'AbsTol', 1e-10, ...
        sprintf('bo %d tai %g Hz', j, bank(j).f));
end
end

function test_poleRadiusAndStability(testCase)
% Hai cực phải nằm đúng bán kính r và BÊN TRONG vòng tròn đơn vị. r >= 1 làm
% filter() trả ra dãy số lớn dần mà không một cảnh báo nào.
bank = design_bpf_bank('r', 0.99);
for j = 1:numel(bank)
    testCase.verifyEqual(max(abs(roots(bank(j).a))), 0.99, 'AbsTol', 1e-12, ...
        sprintf('bo %d', j));
end

bank2 = design_bpf_bank('r', 0.95);
testCase.verifyEqual(max(abs(roots(bank2(1).a))), 0.95, 'AbsTol', 1e-12);
end

function test_bandwidthMatchesFormula(testCase)
% BW -3 dB phải khớp công thức (1-r)*fs/pi. Ca này là thứ cho phép báo cáo
% DẪN GIẢI r = 0.99 thay vì nêu một con số không giải thích được - đúng lý do
% CONTRACTS §3 cấm dùng filterDesigner sinh hệ số nộp bài.
fs = 8000; r = 0.99;
bwFormula = (1 - r) * fs / pi;          % 25.465 Hz
bank = design_bpf_bank('fs', fs, 'r', r);

for j = 1:7
    ff = linspace(bank(j).f - 60, bank(j).f + 60, 24001);
    H  = abs(freqz(bank(j).b, bank(j).a, ff, fs));
    inBand = ff(H >= 1/sqrt(2));
    bw = inBand(end) - inBand(1);
    testCase.verifyEqual(bw, bwFormula, 'RelTol', 0.02, ...
        sprintf('bo %d tai %g Hz', j, bank(j).f));
end
end

function test_zerosAtDcAndNyquist(testCase)
% Ghim VỊ TRÍ hai điểm không: z = ±1, tức |H(0)| = |H(fs/2)| = 0.
%
% Lỗ hổng này do kiểm thử đột biến tìm ra: đổi b = [1 0 -1] thành [1 0 1] dời
% hai điểm không sang z = ±j (triệt 2000 Hz thay vì triệt DC và fs/2), mà KHÔNG
% ca nào trong file đỏ. Lý do các ca kia không bắt được: G được chuẩn hóa để
% |H(f0)| = 1 bất kể điểm không nằm đâu, cực không đổi nên băng thông -3 dB
% cũng gần như không đổi, và tín hiệu thử không có thành phần một chiều.
%
% Hậu quả của bản đột biến: |H(0)| = 0.042 thay vì 0 - bộ lọc hết triệt được
% thành phần một chiều, đúng tính chất mà help của design_bpf_bank khẳng định.
fs = 8000;
bank = design_bpf_bank('fs', fs);
for j = 1:numel(bank)
    Hdc = freqz(bank(j).b, bank(j).a, [0 0], fs);
    testCase.verifyEqual(abs(Hdc(1)), 0, 'AbsTol', 1e-12, ...
        sprintf('bo %d: |H(0)| phai bang 0', j));

    % fs/2 đúng bằng biên Nyquist nên lấy sát mép để freqz không kẹp chỉ số.
    Hny = freqz(bank(j).b, bank(j).a, [fs/2 fs/2] - 1e-6, fs);
    testCase.verifyEqual(abs(Hny(1)), 0, 'AbsTol', 1e-8, ...
        sprintf('bo %d: |H(fs/2)| phai bang 0', j));
end
end

function test_bankLayout(testCase)
% Ghim THỨ TỰ: 7 bộ chuẩn trước, 7 bộ hài sau, bộ hài của bin j nằm ở 7+j.
% dtmf_decode_filterbank truy thẳng yj(7+d,:) nên đảo thứ tự làm nó đo nhầm
% bin mà vẫn chạy trơn.
T = dtmf_table();
bank = design_bpf_bank();
testCase.verifyEqual(numel(bank), 14);
testCase.verifyEqual([bank(1:7).f], [T.rowHz T.colHz], 'AbsTol', 1e-12);
testCase.verifyEqual([bank(8:14).f], 2*[T.rowHz T.colHz], 'AbsTol', 1e-12);

testCase.verifyEqual(numel(design_bpf_bank('withHarm', false)), 7);
end

function test_rejectsBadParameters(testCase)
% Hai chốt chặn đặt trong thân hàm (khối arguments là mặt hợp đồng, §2).
testCase.verifyError(@() design_bpf_bank('r', 1),   'design_bpf_bank:unstableR');
testCase.verifyError(@() design_bpf_bank('r', 0),   'design_bpf_bank:unstableR');
testCase.verifyError(@() design_bpf_bank('r', 1.5), 'design_bpf_bank:unstableR');

% fs = 4000: bộ hài cao nhất 2*1477 = 2954 Hz vượt Nyquist 2000 Hz. Không chặn
% thì bộ lọc vẫn dựng ra bình thường với một tần số tâm bị gập phổ.
testCase.verifyError(@() design_bpf_bank('fs', 4000), 'design_bpf_bank:aboveNyquist');
end

% =====================================================================
% Nhóm 2 - nạp hệ số từ file
% =====================================================================

function test_coeffsRoundTrip(testCase)
% Nạp từ file phải TRÙNG KHÍT dựng bằng công thức. Ca này tự sinh file trong
% tempdir chứ không dựa vào data/mat/coeffs.mat có sẵn, để kết quả không phụ
% thuộc việc máy đó đã chạy make_coeffs hay chưa (CONTRACTS §6(b)).
f = [tempname '.mat'];
c = onCleanup(@() delete(f));

bank = design_bpf_bank('coeffs', '');           % '' ép nhánh công thức
meta = struct('fs', 8000, 'r', 0.99, 'withHarm', true);
save(f, 'bank', 'meta');

testCase.verifyEqual(design_bpf_bank('coeffs', f), bank);
end

function test_staleCoeffsAreIgnored(testCase)
% GHIM luật chống hệ số cũ. Nhánh isfile đứng TRƯỚC nhánh công thức, nên một
% file cũ làm mọi thay đổi r mất tác dụng mà không có dấu hiệu nào. Lệch bất kỳ
% trường siêu dữ liệu nào thì phải bỏ file và dựng lại.
f = [tempname '.mat'];
c = onCleanup(@() delete(f));

bank = design_bpf_bank('coeffs', '');
bank(1).b = bank(1).b * 3;                      % dấu nhận biết "đã nạp từ file"
meta = struct('fs', 8000, 'r', 0.99, 'withHarm', true);
save(f, 'bank', 'meta');

% siêu dữ liệu khớp -> nạp, kể cả khi hệ số đã bị bóp méo
testCase.verifyEqual(design_bpf_bank('coeffs', f), bank);

% lệch một trường -> dựng lại, dấu nhận biết biến mất
bR = design_bpf_bank('coeffs', f, 'r', 0.98);
testCase.verifyEqual(max(abs(roots(bR(1).a))), 0.98, 'AbsTol', 1e-12);
testCase.verifyNotEqual(bR(1).b(1), bank(1).b(1));
testCase.verifyEqual(numel(design_bpf_bank('coeffs', f, 'withHarm', false)), 7);

bFs = design_bpf_bank('coeffs', f, 'fs', 16000);
testCase.verifyNotEqual(bFs(1).b(1), bank(1).b(1));
end

function test_corruptCoeffsAreIgnored(testCase)
% File thiếu meta, hoặc bank cụt, cũng phải rơi về nhánh công thức chứ không
% được ném lỗi khó hiểu giữa chừng.
f = [tempname '.mat'];
c = onCleanup(@() delete(f));

bank = design_bpf_bank('coeffs', '');
save(f, 'bank');                                % thiếu meta
testCase.verifyEqual(numel(design_bpf_bank('coeffs', f)), 14);

bank = bank(1:5);
meta = struct('fs', 8000, 'r', 0.99, 'withHarm', true);
save(f, 'bank', 'meta');                        % bank cụt
testCase.verifyEqual(numel(design_bpf_bank('coeffs', f)), 14);
end

% =====================================================================
% Nhóm 3 - bộ giải mã
% =====================================================================

function test_decodesCleanSignal(testCase)
[x, ~, m] = dtmf_generate('0912345');
testCase.verifyEqual(dtmf_decode_filterbank(x), m.keys);
end

function test_matchesOtherDecoders(testCase)
% Ba bộ giải mã chia khung khác nhau và ĐO bằng ba cách hoàn toàn khác nhau
% (IIR bậc 2 / FFT có cửa sổ / ngân hàng 14 bộ lọc), mà phải ra cùng một chuỗi.
% Đây là thứ chứng minh "ba bộ dùng chung luật quyết định" là sự thật.
for s = {'0912345', '159', '*0#', '4826', '12345699'}
    x = dtmf_generate(s{1});
    msg = sprintf('chuoi "%s"', s{1});
    testCase.verifyEqual(dtmf_decode_filterbank(x), s{1}, msg);
    testCase.verifyEqual(dtmf_decode_filterbank(x), dtmf_decode_goertzel(x), msg);
    testCase.verifyEqual(dtmf_decode_filterbank(x), dtmf_decode_fft(x), msg);
end
end

function test_transientNeedsWholeSignalFiltering(testCase)
% GHIM quyết định "lọc toàn bộ tín hiệu MỘT LẦN rồi mới chia khung".
%
% Lọc riêng từng khung là cách viết trực giác nên rất dễ mắc, và nó reset trạng
% thái bộ lọc ở mỗi biên khung. Khung 1 KHÔNG phát hiện được vì lúc đó hai cách
% giống hệt nhau - cả hai cùng khởi động từ trạng thái 0. Từ khung 2 mới lòi ra.
% Đo 22/09/2026: khung 2 mất 56.91%, khung 3 mất 61.13%.
bank = design_bpf_bank();
x    = dtmf_generate('1');
seg  = dtmf_segment(x);
yWhole = filter(bank(1).b, bank(1).a, x);

    function e = eWhole(i)
        id = seg(i).idx;
        e  = sum(yWhole(id(1):id(2)).^2);
    end
    function e = ePerFrame(i)
        id = seg(i).idx;
        e  = sum(filter(bank(1).b, bank(1).a, x(id(1):id(2))).^2);
    end

testCase.verifyEqual(ePerFrame(1), eWhole(1), 'RelTol', 1e-12, ...
    'khung 1 phai bang nhau - ca hai cung bat dau tu trang thai 0');

testCase.verifyGreaterThan((eWhole(2) - ePerFrame(2)) / eWhole(2), 0.40);
testCase.verifyGreaterThan((eWhole(3) - ePerFrame(3)) / eWhole(3), 0.40);
end

function test_harmonicBinFollowsPeak(testCase)
% Ghim quyết định (b) cho nhánh này: bộ hài bám theo ĐỈNH CỦA TỪNG KHUNG, tức
% bank(7+d), chứ không phải một bộ cố định.
%
% Lỗ hổng này do kiểm thử đột biến tìm ra - tôi đã viết ca tương ứng cho
% Goertzel và FFT nhưng quên nhánh ngân hàng bộ lọc. DTMF sạch có E(8) rất nhỏ
% dù chọn bộ nào, nên phải dựng tín hiệu CÓ hài mới phân biệt được.
%
% Tín hiệu: 770 Hz + 1336 Hz (phím '5') cộng năng lượng tại hài bậc 2 của
% 770 Hz, tức 1540 Hz = bank(9). Bám theo đỉnh thì nhìn đúng bank(9), đo được
% E(8) = 0.167 > ngưỡng 0.083 và loại sạch mọi khung. Lấy bộ cố định bank(8)
% (1394 Hz, hài của 697) thì chỉ thấy 0.009, khung qua sạch và hàm trả về '5'
% - một phím KHÔNG hề được bấm. Đây là cổng chống talk-off.
%
% Biên độ 0.5 chọn bằng cách ĐO: dưới 0.4 thì cả hai cách đều cho '5', từ 1.0
% trở lên thì năng lượng hài kéo rho xuống dưới 0.70 nên cả hai cùng loại với
% nhãn 'level' và ca test mất ý nghĩa.
fs = 8000;
t  = (0:2047) / fs;
x  = sin(2*pi*770*t) + 0.5*sin(2*pi*1336*t) + 0.5*sin(2*pi*1540*t);

% Khung 1 mang nhãn 'level' chứ không phải 'harmonic': bộ lọc còn trong quá độ
% nên rho mới đạt 0.38, trượt điều kiện năng lượng TRƯỚC khi chạm điều kiện hài.
% Từ khung 2 trở đi rho lên 0.80-0.90 và 'harmonic' mới là lý do thật.
%
% Khẳng định đúng CHỮ 'harmonic' chứ không chỉ "khác 'none'": nhãn reject là dữ
% liệu dựng histogram lý do loại khung ở Buổi 10, sai nhãn thì biểu đồ sai mà
% chuỗi giải mã vẫn đúng nên không ai thấy.
[keys, info] = dtmf_decode_filterbank(x);
n = numel(info.reject);

testCase.verifyEmpty(keys);
testCase.verifyFalse(any(strcmp(info.reject, 'none')));
testCase.verifyEqual(info.reject(2:end), repmat({'harmonic'}, 1, n-1));
testCase.verifyEqual(info.reject{1}, 'level');
end

function test_infoShape(testCase)
x = dtmf_generate('0912345');
[~, info] = dtmf_decode_filterbank(x);
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
% Quyết định (e), y hệt hai bộ kia. Nhánh này dùng frameN = 205 nên tâm khung
% đầu tiên là 205/(2*8000) - trùng Goertzel, khác FFT.
x = dtmf_generate('0912345');
[~, info] = dtmf_decode_filterbank(x);
seg = dtmf_segment(x);

testCase.verifyEqual(info.tFrame, ...
    arrayfun(@(s) (s.tStart + s.tEnd)/2, seg), 'AbsTol', 1e-12);
testCase.verifyEqual(info.tFrame(1), 205/(2*8000), 'AbsTol', 1e-12);
testCase.verifyTrue(all(diff(info.tFrame) > 0));
end

function test_confInRange(testCase)
x = dtmf_addnoise(dtmf_generate('0912345'), 'snrDb', 15);
[~, info] = dtmf_decode_filterbank(x);

testCase.verifyTrue(all(info.conf >= 0 & info.conf <= 1));
testCase.verifyEqual(info.conf == 0, ~strcmp(info.reject, 'none'));
end

function test_energyScaleIsNormalized(testCase)
% Ghim quyết định (a) cho nhánh miền thời gian: mẫu số là năng lượng khung ĐẦU
% VÀO, KHÔNG có thừa số N/2 - đầu ra bộ lọc là tín hiệu chứ không phải vạch phổ.
%
% Khác hai nhánh kia ở một điểm quan trọng: rho ở đây CÓ THỂ vượt 1 (đo được
% 3.08). Tử số là năng lượng đầu ra bộ lọc, còn trễ sau đầu vào đúng một thời
% hằng, nên ở khung khoảng lặng mẫu số sụp mà tử số vẫn còn dư âm. Đừng "sửa"
% ca này thành rho <= 1.05 như ở test_decode_fft.
x = dtmf_generate('0912345');
[~, info] = dtmf_decode_filterbank(x);
rho = sum(info.E(1:7, :), 1);
acc = strcmp(info.reject, 'none');

testCase.verifyGreaterThanOrEqual(min(rho(acc)), 0.70);
testCase.verifyGreaterThan(max(rho), 0.90);
testCase.verifyTrue(all(isfinite(rho)));
end

function test_amplitudeInvariance(testCase)
x = dtmf_generate('0912345');
testCase.verifyEqual(dtmf_decode_filterbank(0.01*x), dtmf_decode_filterbank(x));
end

function test_repeatedKeysAcrossAllAlignments(testCase)
% Quét CẠN 41 cách căn lề của hop = 205, cộng phím lặp ở mọi vị trí.
%
% Đây là ca đắt giá nhất cả file. Với minRun = 1 nó hỏng 29/42: dư âm bộ lọc
% làm một khung trong khoảng lặng vẫn được nhận, rồi quá độ ở đầu tone kế tiếp
% loại khung ngay sau đó, để lại một dải cô lập dài đúng một khung -> thừa một
% ký tự. Luật "dải >= 2 khung" (§6(f)) là thứ duy nhất chặn được.
testCase.verifyEqual(gcd(1200, 205), 5);        % 205/5 = 41 cach can le

for L = 0:41
    s = [repmat('1', 1, L) '99'];
    testCase.verifyEqual(dtmf_decode_filterbank(dtmf_generate(s)), s, ...
        sprintf('L = %d', L));
end
end

function test_allTwelveKeys(testCase)
T = dtmf_table();
s = reshape(T.keys', 1, []);
testCase.verifyEqual(dtmf_decode_filterbank(dtmf_generate(s)), s);
end

function test_survivesNoiseBelowOtherMethods(testCase)
% Kết quả so sánh chính của Chủ đề 4: ở 4 dB nhánh này còn đọc đúng trong khi
% Goertzel chỉ đạt 0.02 và FFT 0.00. Lý do giải thích được: 14 bộ cộng hưởng
% BW 25.5 Hz loại gần hết nhiễu NGOÀI BĂNG trước khi đo năng lượng, còn hai
% nhánh kia lấy năng lượng khung thô làm mẫu số nên nhiễu kéo rho xuống.
[x, ~, m] = dtmf_generate('0912345');
ok = 0;
rng(2026);
for t = 1:10
    ok = ok + strcmp(dtmf_decode_filterbank(dtmf_addnoise(x, 'snrDb', 4)), m.keys);
end
testCase.verifyGreaterThanOrEqual(ok, 8);
end

function test_silenceDecodesToNothing(testCase)
[keys, info] = dtmf_decode_filterbank(zeros(1, 4000));

testCase.verifyEmpty(keys);
testCase.verifyClass(keys, 'char');
testCase.verifyTrue(all(strcmp(info.reject, 'level')));
testCase.verifyTrue(all(info.rowIdx == 0));
testCase.verifyTrue(all(isfinite(info.E(:))));
end

function test_emptyWhenShorterThanFrame(testCase)
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
[varargout{1}, varargout{2}] = dtmf_decode_filterbank(y);
end
