function tests = test_run
%TEST_RUN Unit test cho app/dtmf_run - lớp trung gian giữa giao diện và src/.
tests = functiontests(localfunctions);
end

function S = baseState(method)
% Trạng thái tối thiểu mà dtmf_run cần đọc.
S = struct('y', dtmf_generate('0912345'), 'fs', 8000, 'method', method);
end

% ---------------------------------------------------------------- điều phối

function test_dispatchesAllThreeMethods(testCase)
% Ba nhánh switch phải gọi đúng ba bộ giải mã. Gõ nhầm tên hàm ở một nhánh thì
% chỉ nhánh đó hỏng, mà giao diện vẫn chạy - nên phải thử đủ cả ba.
%
% Chỉ so keysHat thì KHÔNG phân biệt được nhánh nào đã chạy: trên tín hiệu sạch
% cả ba bộ đều trả '0912345', nên đổi chỗ hai lời gọi trong switch vẫn xanh.
% Dùng hai dấu vân tay đo được:
%   nFrame - fft chạy hop 128 nên ra 61 khung, hai bộ kia hop 205 ra 39 (§7.3);
%   rhoMax - dư âm bộ lọc trong khung lặng làm sum(E(1:7)) của nhánh filterbank
%            vọt lên rất lớn, hai bộ kia luôn <= 1 (§7.6).
mong = struct('fft', [61 0], 'goertzel', [39 0], 'filterbank', [39 1]);
for m = {'fft', 'goertzel', 'filterbank'}
    S = dtmf_run(baseState(m{1}));
    testCase.verifyEqual(S.keysHat, '0912345', ...
        sprintf('Nhánh %s giải mã sai.', m{1}));
    testCase.verifyEmpty(S.lastError, ...
        sprintf('Nhánh %s báo lỗi: %s', m{1}, S.lastError));

    v = mong.(m{1});
    testCase.verifyEqual(numel(S.info.conf), v(1), ...
        sprintf('Nhánh %s cho %d khung, chờ %d.', m{1}, numel(S.info.conf), v(1)));
    testCase.verifyEqual(max(sum(S.info.E(1:7, :), 1)) > 1, logical(v(2)), ...
        sprintf('Dấu vân tay rho của nhánh %s không khớp.', m{1}));
end
end

function test_invalidMethodDoesNotThrow(testCase)
% Tên phương pháp sai là lỗi của giao diện, KHÔNG phải sự cố hệ thống: ném lỗi
% ở đây làm sập callback và treo cả app giữa buổi demo.
S = baseState('khong_co_that');
testCase.verifyWarningFree(@() dtmf_run(S));

S = dtmf_run(S);
testCase.verifyNotEmpty(S.lastError);
testCase.verifySubstring(S.lastError, 'khong_co_that');
testCase.verifyEmpty(S.keysHat);
end

function test_decoderErrorIsCaught(testCase)
% Lỗi từ tầng src/ cũng phải biến thành S.lastError chứ không văng lên UI.
% Thiếu trường .fs là cách dựng lỗi thật mà không phải sửa src/.
S = rmfield(baseState('fft'), 'fs');
testCase.verifyWarningFree(@() dtmf_run(S));

S = dtmf_run(S);
testCase.verifyNotEmpty(S.lastError);
end

function test_clearsErrorFromPreviousRun(testCase)
% Chạy thành công phải XÓA lỗi cũ. Thiếu bước đặt lại, nhật ký giao diện treo
% mãi một thông báo đã cũ và người dùng tưởng lần chạy này cũng hỏng.
S = baseState('fft');
S.lastError = 'loi cu con treo';
S = dtmf_run(S);
testCase.verifyEmpty(S.lastError);
end

function test_lastErrorEmptyIsOneByZero(testCase)
% Luật §2: mọi giá trị rỗng là 1×0, không phải '' (0×0).
S = dtmf_run(baseState('fft'));
testCase.verifyClass(S.lastError, 'char');
testCase.verifySize(S.lastError, [1 0]);
end

% ---------------------------------------------------------------- quyết định (h)

function test_removesDcOffsetBeforeDecoding(testCase)
% ĐÂY LÀ LÝ DO §7.7 TỒN TẠI. Độ lệch một chiều 0.2 - tức 40% biên độ đỉnh, mức
% rất thường gặp khi thu từ micro - làm CẢ BA bộ giải mã trả chuỗi rỗng, vì
% sum(frame.^2) ở mẫu số phình lên và rho tụt dưới 0.70.
%
% Bỏ dòng trừ trung bình thì ca này đỏ ở cả ba nhánh.
for m = {'fft', 'goertzel', 'filterbank'}
    S = baseState(m{1});
    S.y = S.y + 0.2;
    S = dtmf_run(S);
    testCase.verifyEqual(S.keysHat, '0912345', ...
        sprintf('Nhánh %s không trừ trung bình.', m{1}));
end
end

function test_doesNotOverwriteY(testCase)
% S.y phải nguyên vẹn TỪNG BIT sau khi chạy: ui_plot_wave vẽ S.y, nên ghi đè
% bằng bản đã trừ trung bình là vẽ một tín hiệu khác cái người dùng đã nghe.
S = baseState('fft');
S.y = S.y + 0.2;
yGoc = S.y;
S = dtmf_run(S);
testCase.verifyEqual(S.y, yGoc);
end

function test_computesISelAndThr(testCase)
% iSel và thr do dtmf_run tính, vì tầng UI không được phép tính toán - §6(h).
S = dtmf_run(baseState('goertzel'));

[~, iMong] = max(S.info.conf);
testCase.verifyEqual(S.iSel, iMong);

E = S.info.E(:, S.iSel);
testCase.verifyEqual(S.thr, 0.5 * min(max(E(1:4)), max(E(5:7))), 'AbsTol', 1e-12);

% Ngưỡng phải tách được đúng hai cột: đó là điều làm hình ui_plot_bars có nghĩa.
testCase.verifyEqual(nnz(E > S.thr), 2);
end

function test_iSelIsArgmaxOfConf(testCase)
% GHIM luật chọn khung. Stub cũ từng ghi "khung cuối có reject khác 'none'" -
% một luật KHÁC, cho khung khác trên cùng tín hiệu.
S = dtmf_run(baseState('fft'));
cuoiKhongBiLoai = find(~strcmp(S.info.reject, 'none'), 1, 'last');

testCase.verifyEqual(S.info.conf(S.iSel), max(S.info.conf));
testCase.verifyNotEqual(S.iSel, cuoiKhongBiLoai);
end

function test_emptySignalGivesEmptyOutputs(testCase)
% Giao diện lúc mới mở chưa có tín hiệu nào. Không được ném lỗi, và info phải
% đúng hình dạng hợp đồng để ui_refresh đọc thẳng mà không cần nhánh riêng.
S = baseState('fft');
S.y = zeros(1, 0);
S = dtmf_run(S);

testCase.verifyEmpty(S.lastError);
testCase.verifyEmpty(S.keysHat);
testCase.verifyEqual(S.iSel, 0);
testCase.verifyEqual(S.thr, 0);
testCase.verifySize(S.info.E, [8 0]);
testCase.verifySize(S.info.conf, [1 0]);
testCase.verifyEmpty(S.info.reject);
end

function test_doesNotDraw(testCase)
% Luật §2: dtmf_run KHÔNG được vẽ. Một figure bật lên từ lớp trung gian là sai
% kiến trúc, và trong matlab -batch thì nó làm treo phiên chạy.
n0 = numel(findall(groot, 'Type', 'figure'));
dtmf_run(baseState('filterbank'));
testCase.verifyEqual(numel(findall(groot, 'Type', 'figure')), n0);
end
