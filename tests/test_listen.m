function tests = test_listen
%TEST_LISTEN Unit test cho app/dtmf_listen - giải mã theo luồng cho chế độ micro.
%
% Tiêu chí nghiệm thu chính: chặt một tín hiệu thành những đoạn dài NGẪU NHIÊN
% rồi đưa lần lượt qua dtmf_listen phải cho ĐÚNG chuỗi phím và đúng số khung
% như đưa cả tín hiệu một lần qua bộ giải mã khối. Nhờ vậy mọi số liệu đo trên
% bộ giải mã khối ở Chương 4 cũng là số liệu của chế độ nghe trực tiếp.
tests = functiontests(localfunctions);
end

function L = moi(method)
% Trạng thái luồng mới cho một phương pháp.
L = dtmf_listen(struct('fs', 8000, 'method', method));
end

function L = choAn(L, y, doDai)
% Đưa y vào luồng theo từng đoạn. doDai là vô hướng (đoạn đều) hoặc một hàm
% trả về độ dài đoạn kế tiếp (đoạn ngẫu nhiên).
i = 1;
while i <= numel(y)
    if isa(doDai, 'function_handle')
        n = doDai();
    else
        n = doDai;
    end
    L = dtmf_listen(L, y(i:min(i+n-1, end)));
    i = i + n;
end
end

% ------------------------------------------------------- luồng = khối

function test_streamMatchesBlockAllMethods(testCase)
% So từng ca: chuỗi 10 phím ngẫu nhiên, lề đầu ngẫu nhiên để thử nhiều cách
% căn khung, đoạn dài ngẫu nhiên 1..1500 mẫu. Đo 29/09/2026 trên 96 ca (thêm
% mức 20 và 6 dB): 0 ca lệch. Ở đây giữ tín hiệu sạch và 10 dB cho test nhanh.
%
% Khối được trừ trung bình TOÀN tín hiệu như dtmf_run; luồng trừ trung bình
% từng cửa sổ. Hai cách khác nhau một hằng số rất nhỏ nên phải cùng kết quả.
rng(2026);
for snr = [Inf 10]
    for lan = 1:3
        keys = '0123456789*#';
        keys = keys(randi(12, 1, 10));
        x = [zeros(1, randi(900)), dtmf_generate(keys), zeros(1, 500)];
        y = x;
        if isfinite(snr)
            y = dtmf_addnoise(x, 'snrDb', snr);
        end

        for m = {'fft', 'goertzel', 'filterbank'}
            f = str2func(['dtmf_decode_' m{1}]);
            [kKhoi, infoKhoi] = f(y - mean(y));

            L = choAn(moi(m{1}), y, @() randi(1500));

            ca = sprintf('%s, SNR %g dB, chuỗi %s', m{1}, snr, keys);
            testCase.verifyEmpty(L.lastError, ca);
            testCase.verifyEqual(L.keysHat, kKhoi, ca);
            testCase.verifyEqual(L.nFrame, numel(infoKhoi.conf), ca);
        end
    end
end
end

function test_chunkSizeDoesNotChangeFrameDecisions(testCase)
% Đoạn 1 mẫu (tệ nhất: mỗi lần gọi thêm đúng một mẫu) và một đoạn duy nhất
% phải cho cùng phán quyết TỪNG KHUNG, không chỉ cùng chuỗi phím.
y = dtmf_generate('59');
for m = {'fft', 'goertzel', 'filterbank'}
    A = choAn(moi(m{1}), y, 1);
    B = choAn(moi(m{1}), y, numel(y));

    testCase.verifyEqual(A.keysHat, '59', m{1});
    testCase.verifyEqual(A.keysHat, B.keysHat, m{1});
    testCase.verifyEqual(A.info.rowIdx, B.info.rowIdx, m{1});
    testCase.verifyEqual(A.info.colIdx, B.info.colIdx, m{1});
    testCase.verifyEqual(A.info.reject, B.info.reject, m{1});
end
end

% ---------------------------------------------------------- báo phím sớm

function test_keyIsReportedBeforeToneEnds(testCase)
% Lý do tồn tại của chế độ nghe trực tiếp: phím hiện ra lúc âm CÒN đang kêu,
% không phải sau khi thu xong. Đo 29/09/2026 với đoạn 50 mẫu, quét 41 cách căn
% lề: FFT 40-60 ms, Goertzel 49-74 ms, ngân hàng bộ lọc 65-90 ms sau lúc âm
% bắt đầu - cả ba đều trước khi âm 100 ms (800 mẫu) tắt.
%
% Goertzel có cận lý thuyết: khung đầu nằm trọn trong âm bắt đầu muộn nhất
% 204 mẫu sau lúc âm bắt đầu, cần minRun = 2 khung, cộng một đoạn 50 mẫu:
% 204 + 2*205 + 50 = 664.
tran = struct('fft', 800, 'goertzel', 664, 'filterbank', 800);
for m = {'fft', 'goertzel', 'filterbank'}
    for lech = 0:40:400
        batDau = 400 + lech;
        y = [zeros(1, batDau), dtmf_generate('5'), zeros(1, 400)];

        L = moi(m{1});
        i = 1;
        while i <= numel(y) && isempty(L.keysHat)
            L = dtmf_listen(L, y(i:min(i+49, end)));
            i = i + 50;
        end

        testCase.verifyEqual(L.keysHat, '5', m{1});
        testCase.verifyLessThanOrEqual(L.nSample - batDau, tran.(m{1}), ...
            sprintf('%s, lề %d: phím báo sau %d mẫu.', m{1}, lech, L.nSample - batDau));
    end
end
end

function test_heldKeyIsReportedOnce(testCase)
% Giữ phím 2 giây = ~78 khung liên tiếp cùng phím: đúng MỘT ký tự, và newKeys
% chỉ khác rỗng ở đúng một lần gọi. Dải dựng lại trong gopPhim bị kẹp ở 64
% khung, nên ca này cũng thử luôn chỗ kẹp.
[x, ~, ~] = dtmf_generate('5', 'toneMs', 2000);
y = [zeros(1, 300), x, zeros(1, 300)];

L = moi('goertzel');
soLanBao = 0;
for i = 1:400:numel(y)
    L = dtmf_listen(L, y(i:min(i+399, end)));
    soLanBao = soLanBao + ~isempty(L.newKeys);
end

testCase.verifyEqual(L.keysHat, '5');
testCase.verifyEqual(soLanBao, 1);
end

function test_repeatedKeyGivesTwoCharacters(testCase)
% Khoảng nghỉ 50 ms giữa hai lần bấm cùng phím phải cắt dải ở cả luồng, như
% ở khối (CONTRACTS §6(f)): '55' ra hai ký tự chứ không phải một.
y = dtmf_generate('5599');
for m = {'fft', 'goertzel', 'filterbank'}
    L = choAn(moi(m{1}), y, 400);
    testCase.verifyEqual(L.keysHat, '5599', m{1});
end
end

% -------------------------------------------------------------- hiển thị

function test_displayWindowIsBoundedAndConsistent(testCase)
% Nghe 5 giây: L.y giữ đúng winSec = 3 giây cuối, info chỉ gồm khung nằm trọn
% trong L.y, tFrame tính từ mẫu đầu của L.y, iSel và thr theo công thức của
% dtmf_run (CONTRACTS §6(h)). Sai một trong số đó thì trục thanh vẽ khung này
% mà phụ đề ghi thời điểm của khung khác.
y = dtmf_generate(repmat('0912345', 1, 5));
y = y(1:5*8000);
L = choAn(moi('goertzel'), y, 400);

testCase.verifyNumElements(L.y, 3*8000);
testCase.verifyEqual(L.y, y(end-3*8000+1:end));

n = numel(L.info.conf);
testCase.verifyGreaterThan(n, 0);
testCase.verifySize(L.info.E, [8 n]);
testCase.verifyNumElements(L.info.rowIdx, n);
testCase.verifyNumElements(L.info.reject, n);
testCase.verifyGreaterThanOrEqual(L.info.tFrame(1), 205/2/8000);
testCase.verifyLessThanOrEqual(L.info.tFrame(end), 3 - 205/2/8000);
testCase.verifyTrue(all(diff(L.info.tFrame) > 0));

[~, iMax] = max(L.info.conf);
testCase.verifyEqual(L.iSel, iMax);
E = L.info.E(:, L.iSel);
testCase.verifyEqual(L.thr, 0.5 * min(max(E(1:4)), max(E(5:7))));
end

function test_initGivesEmptyOneByZeroState(testCase)
% Khởi tạo xong là vẽ được ngay: rỗng đúng cỡ 1×0 (luật CONTRACTS §2), iSel =
% 0 để ui_plot_bars xóa trục.
L = moi('goertzel');

testCase.verifyEmpty(L.lastError);
testCase.verifyClass(L.keysHat, 'char');
testCase.verifySize(L.keysHat, [1 0]);
testCase.verifySize(L.y, [1 0]);
testCase.verifySize(L.info.E, [8 0]);
testCase.verifyEqual(L.iSel, 0);
testCase.verifyEqual(L.nSample, 0);
end

function test_columnChunkIsAccepted(testCase)
% getaudiodata trả vector CỘT. Luồng phải nhận cả hai hướng.
y = dtmf_generate('7');
L = dtmf_listen(moi('goertzel'), y');
testCase.verifyEqual(L.keysHat, '7');
end

% ------------------------------------------------------------ sự cố

function test_methodSwitchKeepsKeysAlreadyRead(testCase)
% Đổi bộ giải mã giữa lúc nghe: DTMFApp dựng lại trạng thái bằng phương pháp
% mới và truyền .keysHat cũ vào. Phím đã đọc phải được giữ, phím mới nối sau.
L = dtmf_listen(struct('fs', 8000, 'method', 'fft', 'keysHat', '12'));
L = choAn(L, dtmf_generate('3'), 400);
testCase.verifyEqual(L.keysHat, '123');
end

function test_dcOffsetIsRemovedPerWindow(testCase)
% Micro thường có độ lệch một chiều; DC 0,2 làm CẢ BA bộ giải mã khối trả rỗng
% nếu không trừ trung bình (CONTRACTS §7.7). Luồng trừ trung bình từng cửa sổ.
y = dtmf_generate('0912345') + 0.5;
for m = {'fft', 'goertzel', 'filterbank'}
    L = choAn(moi(m{1}), y, 400);
    testCase.verifyEqual(L.keysHat, '0912345', m{1});
end
end

function test_invalidMethodDoesNotThrow(testCase)
% Giống dtmf_run: tên phương pháp sai thành L.lastError, không thành ngoại lệ
% - ngoại lệ trong tick của micro làm tắt tiếng cả buổi demo.
L = struct('fs', 8000, 'method', 'khong_co_that');
testCase.verifyWarningFree(@() dtmf_listen(L, dtmf_generate('5')));

L = dtmf_listen(L, dtmf_generate('5'));
testCase.verifySubstring(L.lastError, 'khong_co_that');
testCase.verifyEmpty(L.keysHat);
end

function test_nonFiniteChunkIsDroppedWhole(testCase)
% Một NaN lọt vào bộ đệm làm hỏng phép trừ trung bình của mọi cửa sổ chứa nó.
% Đoạn có NaN bị bỏ nguyên, luồng vẫn giải mã tiếp được sau đó.
L = moi('goertzel');
L = dtmf_listen(L, [0.1 NaN 0.2]);
testCase.verifyNotEmpty(L.lastError);
testCase.verifyEqual(L.nSample, 0);

L = choAn(L, dtmf_generate('8'), 400);
testCase.verifyEmpty(L.lastError);
testCase.verifyEqual(L.keysHat, '8');
end
