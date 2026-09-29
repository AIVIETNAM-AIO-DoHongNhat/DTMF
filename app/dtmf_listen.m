function L = dtmf_listen(L, chunk)
%DTMF_LISTEN Giải mã theo luồng: nhận từng đoạn âm thanh ngắn, báo phím ngay khi chắc chắn
% Nghe micro từng chút một và đọc ra phím ngay trong lúc người ta còn đang bấm
%   L = DTMF_LISTEN(L) khởi tạo trạng thái luồng từ L.fs và L.method; các
%   trường còn thiếu được điền mặc định, trường đã có (vd. .keysHat khi đổi
%   phương pháp giữa chừng) được giữ nguyên.
%   L = DTMF_LISTEN(L, CHUNK) nối CHUNK vào luồng, giải mã những khung vừa đủ
%   mẫu rồi ghi kết quả ngược vào L. Gọi lặp lại với từng đoạn micro trả về.
%   Hàm này KHÔNG bao giờ ném lỗi: sự cố ghi vào L.lastError, giống dtmf_run.
%
%   Đây là lớp trung gian thứ hai giữa giao diện và src/, bên cạnh dtmf_run
%   (CONTRACTS §2): dtmf_run giải mã cả tín hiệu một lần, hàm này giải mã dần
%   theo thời gian. Nó KHÔNG có vòng đo công suất riêng - mỗi lần gọi đưa một
%   cửa sổ ngắn qua đúng bộ giải mã khối đang chọn, nên luồng và khối dùng
%   chung một phép đo, một luật quyết định và một luật gộp phím.
%
%   Các bước hoạt động:
%       1. Điền trường còn thiếu; chọn bộ giải mã cùng frameN, hop của nó;
%          đặt lại newKeys và lastError.
%       2. Nối CHUNK vào bộ đệm giải mã và bộ đệm hiển thị (winSec giây cuối).
%       3. m = số khung MỚI đã đủ mẫu. Cửa sổ = H mẫu lịch sử + m khung mới,
%          trừ trung bình cửa sổ, qua dtmf_decode_<method>, rồi bỏ H/hop khung
%          lịch sử ở đầu. H = bội của hop gần 100 ms nhất về phía trên, đủ cho
%          bộ cộng hưởng của ngân hàng bộ lọc chạy hết quá độ (5τ = 62 ms)
%          trước khung đầu tiên được giữ lại.
%       4. Gộp khung thành phím bằng dtmf_debounce trên [dải đang mở, khung
%          mới]; nếu dải đang mở đã sinh ký tự ở lần gọi trước thì bỏ ký tự
%          đầu. Phím được báo ngay khi dải đủ minRun khung, không đợi âm tắt.
%       5. Dọn số liệu cho giao diện: info của các khung nằm trọn trong L.y
%          (tFrame tính từ mẫu đầu của L.y), iSel và thr theo đúng công thức
%          của dtmf_run - CONTRACTS §6(h).
%
%   Input:
%       L: struct trạng thái. Khởi tạo cần .fs [Hz] và .method ('fft' |
%          'goertzel' | 'filterbank'); tùy chọn .winSec, độ dài cửa sổ hiển
%          thị [s] (3). Mọi trường khác do hàm này tự quản lý.
%       chunk: vector double, các mẫu mới nhất theo đúng thứ tự thời gian;
%              hàng hay cột đều được. Bỏ trống hoặc rỗng thì chỉ khởi tạo.
%
%   Output:
%       L: chính struct đó, với các trường người gọi được đọc
%          .keysHat: char 1×K, mọi phím đã đọc từ lúc khởi tạo.
%          .newKeys: char 1×k, phím vừa báo trong LẦN GỌI NÀY; 1×0 nếu không.
%          .y: 1×n double, winSec giây âm thanh cuối cùng (chưa trừ trung bình).
%          .info: số liệu theo khung của các khung nằm trong .y, cùng dạng với
%                 info của ba bộ giải mã.
%          .iSel, .thr: như dtmf_run.
%          .nSample, .nFrame: tổng số mẫu đã nhận và số khung đã quyết định.
%          .lastError: char, thông báo lỗi; rỗng là blanks(0) tức 1×0.
%
%   Example:
%       L = dtmf_listen(struct('fs', 8000, 'method', 'goertzel'));
%       y = dtmf_generate('59');
%       for i = 1:400:numel(y)
%           L = dtmf_listen(L, y(i:min(i+399, end)));
%       end
%       L.keysHat       % '59'

if nargin < 2
    chunk = zeros(1, 0);
end

try
    % Bước 1.
    L = dienMacDinh(L);
    L.newKeys   = blanks(0);
    L.lastError = blanks(0);

    % frameN, hop phải khớp mặc định của từng bộ giải mã khối: test_listen so
    % luồng với khối trên cùng tín hiệu và sẽ đỏ nếu hai bên lệch nhau.
    switch L.method
        case 'fft'
            giaiMa = @dtmf_decode_fft;
            N = 256;  hop = 128;
        case 'goertzel'
            giaiMa = @dtmf_decode_goertzel;
            N = 205;  hop = 205;
        case 'filterbank'
            giaiMa = @dtmf_decode_filterbank;
            N = 205;  hop = 205;
        otherwise
            L.lastError = sprintf('method không hợp lệ: %s', string(L.method));
            return
    end
    H = hop * ceil(0.1 * L.fs / hop);

    % Bước 2. Mẫu không hữu hạn làm hỏng cả cửa sổ lẫn phép trừ trung bình;
    % bỏ nguyên đoạn thay vì để NaN lan sang các khung sau.
    chunk = reshape(double(chunk), 1, []);
    if ~all(isfinite(chunk))
        L.lastError = 'Đoạn âm thanh có giá trị không hữu hạn - đã bỏ qua.';
        return
    end
    L.buf     = [L.buf, chunk];
    L.nSample = L.nSample + numel(chunk);

    nWin = round(L.winSec * L.fs);
    L.y  = [L.y, chunk];
    if numel(L.y) > nWin
        L.y = L.y(end-nWin+1:end);
    end

    % Bước 3. Mọi chỉ số dưới đây là chỉ số TUYỆT ĐỐI trong luồng, mẫu đầu
    % tiên từ lúc khởi tạo là 1; L.buf(1) ứng với mẫu L.bufStart.
    cuoi = L.bufStart + numel(L.buf) - 1;
    m = floor((cuoi - L.next + 1 - N) / hop) + 1;

    if m >= 1
        % Lúc mới khởi tạo chưa đủ H mẫu lịch sử: s0 = 1 = L.next, bỏ 0 khung.
        % Về sau L.next - s0 luôn là bội của hop vì cả H lẫn bước nhảy của
        % L.next đều là bội của hop.
        s0 = max(L.bufStart, L.next - H);
        e0 = L.next + (m-1)*hop + N - 1;
        w  = L.buf(s0 - L.bufStart + 1 : e0 - L.bufStart + 1);

        % Trừ trung bình CỬA SỔ thay cho trung bình toàn tín hiệu như dtmf_run:
        % luồng không có "toàn tín hiệu". Độ lệch một chiều của micro gần như
        % hằng trong 100 ms nên kết quả như nhau - lý do phải trừ: §7.7.
        [~, info] = giaiMa(w - mean(w), 'fs', L.fs, 'frameN', N, 'hop', hop);

        bo  = (L.next - s0) / hop;
        giu = bo + (1:m);
        if size(info.E, 2) ~= bo + m
            error('dtmf_listen:frameCount', ...
                'Bộ giải mã trả %d khung, cần đúng %d.', size(info.E, 2), bo + m);
        end

        L.fr.E      = [L.fr.E, info.E(:, giu)];
        L.fr.rowIdx = [L.fr.rowIdx, info.rowIdx(giu)];
        L.fr.colIdx = [L.fr.colIdx, info.colIdx(giu)];
        L.fr.conf   = [L.fr.conf, info.conf(giu)];
        L.fr.reject = [L.fr.reject, info.reject(giu)];
        L.fr.start  = [L.fr.start, L.next + (0:m-1)*hop];
        L.nFrame    = L.nFrame + m;

        % Bước 4.
        [L, moi]  = gopPhim(L, info.rowIdx(giu), info.colIdx(giu));
        L.newKeys = moi;
        L.keysHat = [L.keysHat, moi];

        % Chỉ giữ lại đúng phần còn cần cho lần gọi sau: H mẫu lịch sử cộng
        % phần đuôi chưa đủ một khung.
        L.next = L.next + m*hop;
        dau    = max(L.bufStart, L.next - H);
        L.buf  = L.buf(dau - L.bufStart + 1 : end);
        L.bufStart = dau;
    end

    % Bước 5. Khung bắt đầu trước mẫu đầu của L.y thì không vẽ được trên cùng
    % trục thời gian với dạng sóng - bỏ luôn khỏi bộ nhớ.
    yDau = L.nSample - numel(L.y) + 1;
    k = L.fr.start >= yDau;
    L.fr.E      = L.fr.E(:, k);
    L.fr.rowIdx = L.fr.rowIdx(k);
    L.fr.colIdx = L.fr.colIdx(k);
    L.fr.conf   = L.fr.conf(k);
    L.fr.reject = L.fr.reject(k);
    L.fr.start  = L.fr.start(k);

    % tFrame là TÂM khung như ba bộ giải mã - quyết định (e).
    L.info = struct('E',      L.fr.E, ...
                    'rowIdx', L.fr.rowIdx, ...
                    'colIdx', L.fr.colIdx, ...
                    'conf',   L.fr.conf, ...
                    'tFrame', (L.fr.start - yDau) / L.fs + N / (2*L.fs), ...
                    'reject', {L.fr.reject});

    L.iSel = 0;
    L.thr  = 0;
    if ~isempty(L.info.conf)
        [~, L.iSel] = max(L.info.conf);
        E = L.info.E(:, L.iSel);
        L.thr = 0.5 * min(max(E(1:4)), max(E(5:7)));
    end
catch ME
    L.lastError = ME.message;
end

end


function L = dienMacDinh(L)
%DIENMACDINH Điền các trường trạng thái còn thiếu, giữ nguyên trường đã có.
% Cell rỗng phải bọc {} trong struct(), nếu không struct() trả mảng struct rỗng.
macDinh = struct( ...
    'fs',        8000, ...
    'method',    'goertzel', ...
    'winSec',    3, ...
    'keysHat',   blanks(0), ...
    'newKeys',   blanks(0), ...
    'buf',       zeros(1, 0), ...
    'bufStart',  1, ...
    'next',      1, ...
    'nSample',   0, ...
    'nFrame',    0, ...
    'y',         zeros(1, 0), ...
    'fr',        struct('E',      zeros(8, 0), ...
                        'rowIdx', zeros(1, 0), ...
                        'colIdx', zeros(1, 0), ...
                        'conf',   zeros(1, 0), ...
                        'reject', {cell(1, 0)}, ...
                        'start',  zeros(1, 0)), ...
    'runRow',    0, ...
    'runCol',    0, ...
    'runLen',    0, ...
    'info',      struct('E',      zeros(8, 0), ...
                        'rowIdx', zeros(1, 0), ...
                        'colIdx', zeros(1, 0), ...
                        'conf',   zeros(1, 0), ...
                        'tFrame', zeros(1, 0), ...
                        'reject', {cell(1, 0)}), ...
    'iSel',      0, ...
    'thr',       0, ...
    'lastError', blanks(0));

ten = fieldnames(macDinh);
for i = 1:numel(ten)
    if ~isfield(L, ten{i})
        L.(ten{i}) = macDinh.(ten{i});
    end
end
end


function [L, moi] = gopPhim(L, r, c)
%GOPPHIM Báo phím mới bằng chính dtmf_debounce, không viết lại luật gộp.
% Dải đang mở (phím của các khung cuối lần trước) được dựng lại bằng repmat rồi
% đặt trước khung mới. dtmf_debounce trên chuỗi ghép cho đúng các ký tự mà nó
% sẽ cho trên toàn luồng, trừ ký tự của dải đang mở nếu dải đó đã đủ dài và
% đã được báo ở lần gọi trước - khi đó nó luôn là ký tự ĐẦU và bị bỏ.
%
% Độ dài dải dựng lại được kẹp ở 64 khung (1,6 s): một phím giữ lâu không làm
% chuỗi ghép phình mãi. Luật chỉ cần biết dải đã đủ minRun hay chưa, nên kẹp
% không đổi kết quả chừng nào minRun <= 64.
n0 = min(L.runLen, 64);
r0 = repmat(L.runRow, 1, n0);
c0 = repmat(L.runCol, 1, n0);

moi = dtmf_debounce([r0, r], [c0, c]);
if n0 > 0 && ~isempty(dtmf_debounce(r0, c0))
    moi = moi(2:end);
end

% Dải đang mở mới: đếm ngược từ khung cuối. Chỉ đo độ dài dải, không quyết
% định sinh ký tự - việc đó đã do dtmf_debounce làm ở trên.
rr = [r0, r];
cc = [c0, c];
n  = numel(rr);
if rr(n) == 0
    L.runRow = 0;
    L.runCol = 0;
    L.runLen = 0;
else
    j = n;
    while j > 1 && rr(j-1) == rr(n) && cc(j-1) == cc(n)
        j = j - 1;
    end
    L.runRow = rr(n);
    L.runCol = cc(n);
    L.runLen = n - j + 1;
end
end
