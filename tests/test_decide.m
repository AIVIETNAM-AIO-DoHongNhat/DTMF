function tests = test_decide
%TEST_DECIDE Unit test cho dtmf_decide - luật quyết định dùng chung cho 3 bộ giải mã.
tests = functiontests(localfunctions);
end

function test_acceptsCleanFrame(testCase)
% Khung sạch của phím '5' (770 Hz + 1336 Hz). Giá trị conf viết cứng để ghim
% CẢ HAI chi tiết của công thức (c): rho bị kẹp min(1, 22) = 1, và mẫu số là
% 2*peakDb = 12 chứ không phải peakDb.
[r, c, cf, rj] = dtmf_decide([1 8 1 1  1 9 1  0.1]');
testCase.verifyEqual(r, 2);
testCase.verifyEqual(c, 2);
testCase.verifyEqual(rj, 'none');
testCase.verifyEqual(cf, 10*log10(8)/12, 'AbsTol', 1e-12);   % 0.752575...
end

function test_rejectsWeakPeak(testCase)
% Hai bin hàng gần bằng nhau (5 và 5.5 -> chênh 0.41 dB < 6 dB): không biết
% chọn hàng nào. Nhóm cột vẫn rõ ràng, nên ca này bắt lỗi chỉ kiểm tra một
% nhóm rồi bỏ qua nhóm kia.
[r, c, cf, rj] = dtmf_decide([5 5.5 1 1  1 9 1  0.1]');
testCase.verifyEqual(rj, 'level');
testCase.verifyEqual([r c], [0 0]);
testCase.verifyEqual(cf, 0);
end

function test_rejectsForwardTwist(testCase)
% Twist thuận = cột mạnh hơn hàng. Ngưỡng 4 dB, kiểm sát hai bên: 3.9 dB qua,
% 4.1 dB trượt. Không thử đúng 4.0 dB vì 10*log10(10^0.4) sai số ở bit cuối,
% ca test sẽ đỏ hay xanh tùy máy chứ không tùy code.
mk = @(p) [1 8 1 1  p/10 p p/10  0.1]';   % cả ba bin cột cùng lên xuống
[~, ~, ~, rjIn]  = dtmf_decide(mk(8*10^0.39));
[~, ~, ~, rjOut] = dtmf_decide(mk(8*10^0.41));
testCase.verifyEqual(rjIn,  'none');
testCase.verifyEqual(rjOut, 'twist');
end

function test_rejectsBackwardTwist(testCase)
% Twist nghịch = hàng mạnh hơn cột, ngưỡng rộng hơn (8 dB) vì đường dây điện
% thoại suy hao tần số cao nhiều hơn. Hai ngưỡng KHÔNG đối xứng: đổi chỗ
% twistFwdDb với twistBwdDb thì ca này đỏ. Ba bin cột phải hạ CÙNG NHAU; giữ
% hai bin phụ ở 1 thì đỉnh cột chỉ còn nhô 1.1 dB, điều kiện 2 chặn trước và
% nhãn ra 'level' - ca test không chạm tới phép thử twist nữa.
mk = @(p) [1 80 1 1  p/10 p p/10  0.1]';
[~, ~, ~, rjIn]  = dtmf_decide(mk(80*10^-0.79));
[~, ~, ~, rjOut] = dtmf_decide(mk(80*10^-0.81));
testCase.verifyEqual(rjIn,  'none');
testCase.verifyEqual(rjOut, 'twist');
end

function test_rejectsHarmonic(testCase)
% E(8) = 5 > 0.5*min(8, 9) = 4. Hài bậc 2 mạnh là dấu hiệu tiếng nói chứ
% không phải tone thuần - bốn điều kiện trước đều qua, chỉ điều kiện 5 chặn.
[r, c, cf, rj] = dtmf_decide([1 8 1 1  1 9 1  5]');
testCase.verifyEqual(rj, 'harmonic');
testCase.verifyEqual([r c], [0 0]);
testCase.verifyEqual(cf, 0);
end

function test_rejectsLowEnergy(testCase)
% E ĐÃ chuẩn hóa theo (a), 7 bin chuẩn chỉ giữ 50% năng lượng khung < 70%:
% hình dạng phổ đẹp nhưng phần lớn năng lượng nằm ngoài 7 bin -> nhiễu.
E = [1 8 1 1  1 9 1  0]' / 22 * 0.5;
[~, ~, ~, rj] = dtmf_decide(E);
testCase.verifyEqual(sum(E(1:7)), 0.5, 'AbsTol', 1e-12);
testCase.verifyEqual(rj, 'level');
end

function test_degenerateInputs(testCase)
% Năm dạng đầu vào suy biến. Ca cuối là cái bẫy Study §10.1: E toàn số hữu
% hạn nên chốt chặn isfinite KHÔNG đỡ, nhưng nhóm hàng toàn 0 làm dRow = 0/0
% = NaN bên trong hàm. Viết điều kiện thành 'if dRow < peakDb' thì NaN < 6 là
% false -> khung rác lọt qua với nhãn 'none' và rowIdx = 1.
bad = { zeros(8,1), ...
        [1 8 1 1  1 9 1  NaN]', ...
        [1 8 1 1  1 Inf 1  0.1]', ...
        [-1 8 1 1  1 9 1  0.1]', ...
        [0 0 0 0  0.001 10 0.001  0]' };

for i = 1:numel(bad)
    msg = sprintf('ca suy bien thu %d', i);
    testCase.verifyWarningFree(@() dtmf_decide(bad{i}), msg);
    [r, c, cf, rj] = dtmf_decide(bad{i});
    testCase.verifyEqual([r c], [0 0], msg);
    testCase.verifyEqual(cf, 0, msg);
    testCase.verifyNotEqual(rj, 'none', msg);
end
end

function test_confInRange(testCase)
% 1000 khung ngẫu nhiên CHƯA chuẩn hóa - thang của chúng lớn hơn 1 rất nhiều.
% Thiếu kẹp min(1, rho) trong công thức (c) thì conf ra hàng chục và ca này
% đỏ ngay. Kèm luôn tương đương hai chiều: conf == 0 khi và chỉ khi bị loại.
rng(0);
for i = 1:1000
    [~, ~, cf, rj] = dtmf_decide(rand(8,1));
    msg = sprintf('khung ngau nhien thu %d', i);
    testCase.verifyGreaterThanOrEqual(cf, 0, msg);
    testCase.verifyLessThanOrEqual(cf, 1, msg);
    testCase.verifyEqual(cf == 0, ~strcmp(rj, 'none'), msg);
end
end

function test_scaleInvariance(testCase)
% Bốn trong năm điều kiện là tỉ số nên bất biến theo thang đo; điều kiện 4 là
% cái duy nhất không. Ghi lại hệ quả: PHÍM không đổi, nhưng conf thì có - vì
% rho bị kẹp. Đừng "sửa" chỗ này thành verifyEqual cho conf.
E = [1 8 1 1  1 9 1  0.1]' / 22 * 0.9;           % rho = 0.9, đã chuẩn hóa
[r1, c1, cf1] = dtmf_decide(E);
[r2, c2, cf2] = dtmf_decide(1e6 * E);
testCase.verifyEqual([r2 c2], [r1 c1]);
testCase.verifyEqual([r1 c1], [2 2]);
testCase.verifyNotEqual(cf2, cf1);
end

function test_rejectsMultiFrameE(testCase)
% Khối arguments khai E (8,:) nên 8×n lọt qua được. Không chặn thì max() chạy
% theo cột, bốn đầu ra thành vector 1×n và Buổi 4 nhận kết quả sai im lặng.
testCase.verifyError(@() dtmf_decide(ones(8,3)), 'dtmf_decide:notOneFrame');
testCase.verifyError(@() dtmf_decide(zeros(8,0)), 'dtmf_decide:notOneFrame');
end
