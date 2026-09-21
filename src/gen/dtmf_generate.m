function [x, t, meta] = dtmf_generate(keys, opt)
%DTMF_GENERATE Tổng hợp tín hiệu DTMF từ chuỗi phím bấm
% Trả về đoạn âm thanh mà một chiếc điện thoại sẽ phát ra khi bấm dãy số đó
%   [X, T, META] = DTMF_GENERATE(KEYS) sinh tín hiệu cho chuỗi phím KEYS.
%   Thêm các cặp tên–giá trị bên dưới để đổi tham số mặc định.
%
%   Mỗi phím phát đồng thời hai sin - một tần số hàng, một tần số cột:
%       x_i(t) = sin(2*pi*fRow*t) + g*sin(2*pi*fCol*t),  g = 10^(twistDb/20)
%   Các tone nối tiếp nhau, xen giữa là khoảng lặng; không có khoảng lặng
%   trước tone đầu tiên. Tone 100 ms / nghỉ 50 ms là mức chốt của dự án,
%   thỏa thời lượng tối thiểu của ITU-T Q.24 (xem CONTRACTS.md).
%
%   Đầu vào:
%       keys - char 1×K, chuỗi phím, ví dụ '0912345678*#'.
%
%   Tham số tên–giá trị (mặc định trong ngoặc):
%       'fs': tần số lấy mẫu [Hz] (8000).
%       'toneMs': thời lượng mỗi tone [ms] (100).
%       'pauseMs': khoảng lặng giữa hai phím liên tiếp [ms] (50).
%       'twistDb': mức tone cột so với tone hàng [dB] (0); > 0: cột mạnh hơn.
%       'ampl': biên độ đỉnh sau chuẩn hóa, thuộc (0, 1] (0.5).
%
%   Đầu ra:
%       x: 1×N double, tín hiệu DTMF, nằm trong [-1, 1].
%       t: 1×N double, trục thời gian [s], t(1) = 0.
%       meta: struct nhãn thời gian, các trường đều 1×K:
%              .keys (char), .onsets [s], .offsets [s], .fRow [Hz], .fCol [Hz].
%
%   Ví dụ:
%       [x, t, meta] = dtmf_generate('51');
%       numel(x)        % 2000 = 800 (tone) + 400 (nghỉ) + 800 (tone)
%       meta.fRow       % [770 697]
%       meta.onsets     % [0 0.15]
%       max(abs(x))     % 0.5
arguments
    keys (1,:) char
    opt.fs (1,1) double = 8000
    opt.toneMs (1,1) double = 100
    opt.pauseMs (1,1) double = 50
    opt.twistDb (1,1) double = 0
    opt.ampl (1,1) double = 0.5
end

% Tra bảng tần số
T = dtmf_table();
K = numel(keys);

%% 1. Kiểm tra đầu vào
% Bắt lỗi ở đây để báo rõ ràng, thay vì lỗi khó hiểu từ containers.Map
% hoặc tukeywin phía dưới.
if opt.ampl <= 0 || opt.ampl > 1
    error('dtmf_generate:badAmpl', ...
        'Tham số ampl phải thuộc (0, 1], nhận được %g.', opt.ampl);
end

% num2cell('51') -> {'5', '1'}; isKey nhận cell thì trả về mảng logic 1×K.
isValid = isKey(T.map, num2cell(keys));
if ~all(isValid)
    error('dtmf_generate:unknownKey', ...
        'Ký tự không phải phím DTMF: %s', keys(~isValid));
end

%% 2. Quy đổi thời lượng [ms] sang số mẫu
% Số mẫu = thời lượng [s] × fs [Hz]; chia 1000 vì đầu vào tính bằng ms.
nTone  = round(opt.fs * opt.toneMs  / 1000);
nPause = round(opt.fs * opt.pauseMs / 1000);

if nTone < 1
    error('dtmf_generate:badToneMs', ...
        'toneMs quá ngắn: fs = %g Hz và toneMs = %g ms cho ra 0 mẫu.', ...
        opt.fs, opt.toneMs);
end

% Chuỗi rỗng vẫn hợp lệ: trả về tín hiệu rỗng.
if K == 0
    x = zeros(1, 0);
    t = zeros(1, 0);
    meta = struct('keys', keys, 'onsets', [], 'offsets', [], ...
                  'fRow', [], 'fCol', []);
    return
end

%% 3. Chuẩn bị các đại lượng dùng chung cho mọi tone
N = K * nTone + (K - 1) * nPause;   % K tone, xen giữa (K-1) khoảng lặng

x = zeros(1, N);            % cấp phát trước, nhanh hơn nối mảng dần
t = (0:N-1) / opt.fs;       % trục thời gian [s]

% Trục thời gian riêng của MỘT tone, luôn bắt đầu từ 0, nhờ vậy tone nào
% cũng khởi pha 0 dù nằm ở đâu trong chuỗi.
tTone = (0:nTone-1) / opt.fs;

g = 10^(opt.twistDb / 20);  % biên độ tone cột; twistDb = 6 -> g ≈ 2

% Cửa sổ Tukey côn 5%: vào/ra tone mượt thay vì bật tắt đột ngột - bước
% nhảy biên độ làm trải rộng phổ và nghe thành tiếng "click".
% tukeywin trả về vector CỘT nên cần .' để chuyển thành vector hàng.
wTaper = tukeywin(nTone, 0.05).';

meta = struct('keys', keys, ...
              'onsets',  zeros(1, K), ...
              'offsets', zeros(1, K), ...
              'fRow',    zeros(1, K), ...
              'fCol',    zeros(1, K));

%% 4. Sinh từng tone và đặt vào đúng vị trí trong x
for i = 1:K
    rc   = T.map(keys(i));      % ký tự phím -> [chỉ số hàng, chỉ số cột]
    fRow = T.rowHz(rc(1));
    fCol = T.colHz(rc(2));

    % Tone hàng biên độ 1, tone cột biên độ g; .* là nhân từng phần tử.
    seg = sin(2*pi*fRow*tTone) + g * sin(2*pi*fCol*tTone);
    seg = seg .* wTaper;

    % Mỗi phím đứng trước chiếm trọn (nTone + nPause) mẫu; cộng 1 vì chỉ
    % số MATLAB tính từ 1.
    iStart = (i-1) * (nTone + nPause) + 1;
    iEnd = iStart + nTone - 1;
    x(iStart:iEnd) = seg;

    % Trừ 1 để đổi chỉ số mẫu (từ 1) sang thời gian (từ 0).
    meta.onsets(i) = (iStart - 1) / opt.fs;
    meta.offsets(i) = iEnd / opt.fs;
    meta.fRow(i) = fRow;
    meta.fCol(i) = fCol;
end

%% 5. Chuẩn hóa biên độ
% Đưa đỉnh |x| về đúng opt.ampl: tín hiệu không bao giờ vượt [-1, 1], và
% mức ra giữ nguyên khi đổi twistDb.
peak = max(abs(x));
if peak > 0
    x = x * (opt.ampl / peak);
end

end
