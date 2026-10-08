function M = make_dataset(outDir)
%MAKE_DATASET Sinh bộ dữ liệu âm thanh có nhãn vào data/wav
% Một kho đoạn ghi âm bấm phím có sẵn đáp án, để thử ba bộ giải mã và nút "Mở tệp âm thanh…"
%   M = MAKE_DATASET() ghi các tệp âm thanh vào data/wav/<nhóm>/, bảng nhãn
%   data/wav/manifest.csv và tệp nhiễu data/wav/speech_tong_dai.wav, rồi trả
%   bảng nhãn về.
%   M = MAKE_DATASET(OUTDIR) ghi vào OUTDIR thay cho data/wav. test_dataset
%   dùng cách này để sinh lại vào thư mục tạm rồi so với bản trên đĩa.
%
%   Mỗi nhóm đặt rng(seed) riêng và WAV không chứa dấu thời gian, nên chạy lại
%   cho đúng từng mẫu. Sửa dtmf_generate hay dtmf_addnoise thì chạy lại hàm
%   này, nếu không test_dataset báo bộ dữ liệu đã cũ.
%
%   Các bước hoạt động:
%       1. Dựng speech_tong_dai.wav bằng cách nối các câu thu sẵn của tổng đài
%          trong data/giong_tong_dai, đổi 16 kHz -> 8 kHz bằng dtmf_readaudio.
%          Đây là bản giọng cố định mà các số liệu của báo cáo dựa vào, KHÔNG
%          phải web/src/ivr/voice: thu lại giọng cho web không được làm đổi bộ
%          dữ liệu (thay 4 phím và lời chào ngày 08/10/2026 đã làm lệch 14 tệp).
%          dtmf_addnoise(..., 'type', 'speech') đọc đúng tệp này.
%       2. Sinh mười nhóm, mỗi tệp một dòng nhãn gồm chuỗi phím thật, kỳ vọng
%          và thông số đã dùng. Kỳ vọng 'dung' là cả ba bộ giải mã phải đọc
%          đúng từng phím, 'rong' là cả ba phải trả chuỗi rỗng, 'thong_ke' là
%          dưới vách nhiễu hoặc ngoài giới hạn đã biết nên chỉ dùng để đo.
%          Bộ giải mã nào đang sai kỳ vọng thì ghi tên vào ngoaiLe kèm lý do
%          trong ghiChu, để hạn chế nằm ngay trong dữ liệu (CONTRACTS §7.13).
%       3. Tệp có đỉnh vượt 0.95 thì hạ cả tệp về 0.95 trước khi ghi để WAV số
%          nguyên không cắt ngọn. Nhân cả tệp với một hằng số không đổi SNR và
%          không đổi kết quả giải mã.
%       4. Ghi manifest.csv (UTF-8, mọi ô chữ trong ngoặc kép để số điện
%          thoại giữ số 0 đầu).
%
%   Input:
%       outDir: char, thư mục đích; bỏ trống là data/wav của repo.
%
%   Output:
%       M: table, mỗi dòng một tệp, các cột
%          .tep (đường dẫn tương đối, gạch chéo xuôi), .nhom, .phim, .kyVong,
%          .ngoaiLe (bộ giải mã đang sai kỳ vọng ở tệp này, '' nếu không có),
%          .fs [Hz], .kenh, .bit, .nhieu, .snrDb [dB], .twistDb [dB],
%          .lechPct [%], .toneMs [ms], .nghiMs [ms], .ghiChu.
%          NaN là không áp dụng (không nhiễu, nhịp ngẫu nhiên).
%
%   Example:
%       addpath('scripts');
%       M = make_dataset();
%       groupcounts(M, 'nhom')

root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root, 'src')));
addpath(fullfile(root, 'app'));             % dtmf_readaudio
repoWav = fullfile(root, 'data', 'wav');
if nargin < 1 || isempty(outDir)
    outDir = repoWav;
end

fs      = 8000;
T       = dtmf_table();
allKeys = reshape(T.keys.', 1, []);         % '123456789*0#'
rows    = cell(200, 15);                  % đủ chỗ, cắt bớt ở bước 4
n       = 0;

% Nhịp bấm tay, cùng thông số với web/src/forensic/scene.ts để hai bên so được.
% Tone ngắn hơn khoảng 77 ms có thể không đủ hai khung trọn (CONTRACTS §7.11).
NGUOI = struct('lead', [1.0 1.6], 'tone', [90 220], 'gap', [140 420], ...
               'group', [350 750], 'jitterDb', 1.5);
VOI   = struct('lead', [1.0 1.6], 'tone', [65 110], 'gap', [45 80], ...
               'group', [], 'jitterDb', 1.5);

%% 1. Tệp nhiễu tiếng nói
vDir = fullfile(root, 'data', 'giong_tong_dai');
d = dir(fullfile(vDir, '*.wav'));
if isempty(d)
    error('make_dataset:noVoice', 'Không thấy giọng thu sẵn trong %s.', vDir);
end
% dir không hứa thứ tự trên mọi hệ điều hành, sắp tên để tệp ra giống nhau.
ten  = sort({d.name});
cau  = cell(1, numel(ten));
lang = zeros(1, round(0.15 * fs));          % 150 ms lặng giữa hai câu
for i = 1:numel(ten)
    v = dtmf_readaudio(fullfile(vDir, ten{i}), 'fs', fs);
    cau{i} = [v - mean(v), lang];
end
s = [cau{:}];
s = s * (0.9 / max(abs(s)));

p = mau('khong_phim');
p.toneMs = NaN;  p.nghiMs = NaN;
p.ngoaiLe = 'filterbank';
p.ghiChu  = ['Giọng tổng đài thu sẵn, nhiễu cho dtmf_addnoise ''speech''. Ngân hàng ' ...
             'bộ lọc đọc nhầm một phím 9 ở 9.65 s, do dao động dư khi câu chào tắt về 0 (§7.13)'];
n = n + 1;  rows(n, :) = ghi(outDir, 'speech_tong_dai.wav', s, fs, '', 'rong', p);

% dtmf_addnoise luôn đọc data/wav của repo, kể cả khi outDir là thư mục khác.
if isempty(dir(fullfile(repoWav, 'speech_*.wav')))
    error('make_dataset:noSpeech', ...
        'Chưa có data/wav/speech_*.wav, chạy make_dataset() một lần trước.');
end

%% 2.1 sach - không nhiễu, nhịp chuẩn 100/50 ms
rng(1);
p = mau('sach');
n = n + 1;  rows(n, :) = ghi(outDir, 'sach/mot_phim_5.wav', dtmf_generate('5'), fs, '5', 'dung', p);
n = n + 1;  rows(n, :) = ghi(outDir, 'sach/tat_ca_phim.wav', dtmf_generate(allKeys), fs, allKeys, 'dung', p);
k = '11990000**##';
p.ghiChu = 'Phím lặp, chỉ tách được nhờ khung bị loại trong khoảng nghỉ';
n = n + 1;  rows(n, :) = ghi(outDir, 'sach/phim_lap.wav', dtmf_generate(k), fs, k, 'dung', p);
p.ghiChu = '';
for i = 1:6
    so = soDienThoai();
    n = n + 1;  rows(n, :) = ghi(outDir, sprintf('sach/so_dt_%02d.wav', i), ...
        dtmf_generate(so), fs, so, 'dung', p);
end

%% 2.2 awgn - năm chuỗi 12 phím, tám mức SNR
% Cùng năm chuỗi ở mọi mức để đường độ chính xác theo SNR chỉ khác nhau ở nhiễu.
rng(2);
chuoi = chuoiNgauNhien(allKeys, 5);
for snr = [20 15 10 8 6 4 2 0]
    for i = 1:numel(chuoi)
        p = mau('awgn');
        p.nhieu = 'awgn';  p.snrDb = snr;
        y = dtmf_addnoise(dtmf_generate(chuoi{i}), 'snrDb', snr, 'type', 'awgn');
        n = n + 1;  rows(n, :) = ghi(outDir, sprintf('awgn/snr%gdB_c%d.wav', snr, i), ...
            y, fs, chuoi{i}, kyVongSnr(snr, 10), p);
    end
end

%% 2.3 hum50 - nhiễu điện lưới 50 Hz
rng(3);
chuoi = chuoiNgauNhien(allKeys, 4);
for snr = [10 5 2.5 0]
    for i = 1:numel(chuoi)
        p = mau('hum50');
        p.nhieu = 'hum50';  p.snrDb = snr;
        y = dtmf_addnoise(dtmf_generate(chuoi{i}), 'snrDb', snr, 'type', 'hum50', 'fs', fs);
        n = n + 1;  rows(n, :) = ghi(outDir, sprintf('hum50/snr%gdB_c%d.wav', snr, i), ...
            y, fs, chuoi{i}, kyVongSnr(snr, 10), p);
    end
end

%% 2.4 speech - tiếng nói qua chính nhánh 'speech' của dtmf_addnoise
rng(4);
chuoi = chuoiNgauNhien(allKeys, 4);
for snr = [20 15 10 5]
    for i = 1:numel(chuoi)
        p = mau('speech');
        p.nhieu = 'speech';  p.snrDb = snr;
        y = dtmf_addnoise(dtmf_generate(chuoi{i}), 'snrDb', snr, 'type', 'speech', 'fs', fs);
        n = n + 1;  rows(n, :) = ghi(outDir, sprintf('speech/snr%gdB_c%d.wav', snr, i), ...
            y, fs, chuoi{i}, kyVongSnr(snr, 10), p);
    end
end

%% 2.5 hien_truong - người bấm tay giữa tiếng nói và nhiễu, bốn mức như #giam-dinh
% bgDb là RMS tiếng nói chia RMS tone, SNR tính trên các mẫu có tone - cùng
% cách đo với scene.ts, nên cao hơn SNR của nhóm awgn khoảng 1.8 dB (§7.11).
rng(5);
canh = {'phong_yen_tinh', NGUOI, NaN, NaN, 'dung'
        'quan_ca_phe',    NGUOI, -20, 20,  'dung'
        'ngoai_duong',    NGUOI, -14, 12,  'thong_ke'
        'cuc_kho',        VOI,   -10,  8,  'thong_ke'};
for c = 1:size(canh, 1)
    for i = 1:4
        so = soDienThoai();
        x  = bamTheoNhip(so, canh{c, 2}, fs);
        y  = tronHienTruong(x, s, canh{c, 3}, canh{c, 4});
        p = mau('hien_truong');
        p.toneMs = NaN;  p.nghiMs = NaN;  p.snrDb = canh{c, 4};
        p.ghiChu = sprintf('%s, không tiếng nói, %s', canh{c, 1}, moTaNhip(canh{c, 2}));
        if ~isnan(canh{c, 3})
            p.nhieu  = 'speech+awgn';
            p.ghiChu = sprintf('%s, tiếng nói %g dB so với tone, %s', canh{c, 1}, ...
                canh{c, 3}, moTaNhip(canh{c, 2}));
        end
        n = n + 1;  rows(n, :) = ghi(outDir, sprintf('hien_truong/%s_%d.wav', canh{c, 1}, i), ...
            y, fs, so, canh{c, 5}, p);
    end
end

%% 2.6 twist - tone cột mạnh/yếu hơn tone hàng
% Giới hạn của dtmf_decide là thuận 4 dB, nghịch 8 dB. Giá trị chọn cách biên
% ít nhất 2 dB vì twist đo được còn lệch theo vị trí bin của từng tần số.
for tw = [2 -6 8 -12]
    p = mau('twist');
    p.twistDb = tw;
    kv = 'dung';
    if tw > 4 || tw < -8
        kv = 'rong';
    end
    n = n + 1;  rows(n, :) = ghi(outDir, sprintf('twist/twist%+gdB.wav', tw), ...
        dtmf_generate(allKeys, 'twistDb', tw), fs, allKeys, kv, p);
end

%% 2.7 lech_tan - cả hai tone lệch cùng một tỉ lệ so với tần số chuẩn
% Sinh ở fs/(1+lech) rồi gán nhãn fs: tần số số f/fs' đọc ở fs thành f*(1+lech).
% Tone vì vậy ngắn đi cùng tỉ lệ (96.6 ms ở +3.5%), không đáng kể.
for lech = [-3.5 -1.5 -0.5 0.5 1.5 3.5]
    p = mau('lech_tan');
    p.lechPct = lech;
    p.toneMs  = 100 / (1 + lech/100);
    p.nghiMs  = 50 / (1 + lech/100);
    kv = 'thong_ke';
    if abs(lech) >= 3.5
        kv = 'rong';
    end
    if lech == -3.5
        p.ngoaiLe = 'filterbank';
        p.ghiChu  = ['Ngân hàng bộ lọc nhận phím 1 từ dao động dư trong khoảng nghỉ, ' ...
                     'ở đúng 697/1209 Hz (§7.13)'];
    end
    x = dtmf_generate(allKeys, 'fs', fs / (1 + lech/100));
    n = n + 1;  rows(n, :) = ghi(outDir, sprintf('lech_tan/lech%+.1fpct.wav', lech), ...
        x, fs, allKeys, kv, p);
end

%% 2.8 nhip - thời lượng tone và khoảng nghỉ
rng(8);
p = mau('nhip');
p.ghiChu = 'Giữ phím 5 trong 800 ms rồi bấm 9, phải ra một chữ 5';
x = [dtmf_generate('5', 'toneMs', 800), zeros(1, 0.05*fs), dtmf_generate('9')];
n = n + 1;  rows(n, :) = ghi(outDir, 'nhip/giu_phim_lau.wav', x, fs, '59', 'dung', p);

for tn = [150 100 80 40; 100 40 50 40]
    p = mau('nhip');
    p.toneMs = tn(1);  p.nghiMs = tn(2);
    k = allKeys;
    kv = 'thong_ke';
    if tn(1) >= 100 && tn(2) >= 50
        kv = 'dung';
    elseif tn(1) == 100
        k = '55559999##00';               % nghỉ ngắn dễ làm dính phím lặp
        p.ghiChu = 'Phím lặp với khoảng nghỉ 40 ms, mức tối thiểu của Q.24';
    end
    if tn(1) == 40
        p.ghiChu = 'Tone 40 ms, mức tối thiểu của Q.24 (giới hạn đã biết, §7.11)';
    end
    n = n + 1;  rows(n, :) = ghi(outDir, sprintf('nhip/tone%d_nghi%d.wav', tn(1), tn(2)), ...
        dtmf_generate(k, 'toneMs', tn(1), 'pauseMs', tn(2)), fs, k, kv, p);
end

for i = 1:3
    so = soDienThoai();
    p = mau('nhip');
    p.toneMs = NaN;  p.nghiMs = NaN;
    p.ghiChu = ['Bấm tay ' moTaNhip(NGUOI)];
    n = n + 1;  rows(n, :) = ghi(outDir, sprintf('nhip/bam_tay_%d.wav', i), ...
        bamTheoNhip(so, NGUOI, fs), fs, so, 'dung', p);
end
for i = 1:2
    so = soDienThoai();
    p = mau('nhip');
    p.toneMs = NaN;  p.nghiMs = NaN;
    p.ghiChu = ['Bấm vội ' moTaNhip(VOI)];
    n = n + 1;  rows(n, :) = ghi(outDir, sprintf('nhip/bam_voi_%d.wav', i), ...
        bamTheoNhip(so, VOI, fs), fs, so, 'thong_ke', p);
end

%% 2.9 dinh_dang - cùng một số, nhiều tần số lấy mẫu, độ sâu bit, kênh và mức
% Kiểm đường nhập tệp của DTMFApp (dtmf_readaudio rồi dtmf_run), không kiểm
% bộ giải mã: tệp nào ở đây cũng sạch. Không có WAV float vì audiowrite ghi
% khối PEAK kèm dấu thời gian, mỗi lần sinh lại ra một tệp khác byte.
k = '0912345678#';
p = mau('dinh_dang');
x = dtmf_generate(k, 'fs', 44100);
p.ghiChu = 'Hai kênh, kênh phải nhỏ hơn 3 dB';
n = n + 1;  rows(n, :) = ghi(outDir, 'dinh_dang/fs44100_stereo.wav', [x; 0.7*x].', 44100, k, 'dung', p);
p.ghiChu = '';
n = n + 1;  rows(n, :) = ghi(outDir, 'dinh_dang/fs48000_24bit.wav', ...
    dtmf_generate(k, 'fs', 48000), 48000, k, 'dung', p, 24);
n = n + 1;  rows(n, :) = ghi(outDir, 'dinh_dang/fs16000.flac', ...
    dtmf_generate(k, 'fs', 16000), 16000, k, 'dung', p);
p.ghiChu = 'Tỉ số 8000/11025 = 320/441 không nguyên';
n = n + 1;  rows(n, :) = ghi(outDir, 'dinh_dang/fs11025.wav', ...
    dtmf_generate(k, 'fs', 11025), 11025, k, 'dung', p);
p.ghiChu = '';
n = n + 1;  rows(n, :) = ghi(outDir, 'dinh_dang/fs8000_8bit.wav', dtmf_generate(k), fs, k, 'dung', p, 8);
p.ghiChu = 'Lệch một chiều 0.2 và 0.5 s lặng hai đầu, như micro (§7.7)';
x = [zeros(1, fs/2), dtmf_generate(k), zeros(1, fs/2)] + 0.2;
n = n + 1;  rows(n, :) = ghi(outDir, 'dinh_dang/lech_dc_0.2.wav', x, fs, k, 'dung', p);
p.ghiChu = 'Đỉnh 0.01, tức -40 dBFS';
n = n + 1;  rows(n, :) = ghi(outDir, 'dinh_dang/muc_thap_-40dBFS.wav', ...
    dtmf_generate(k, 'ampl', 0.01), fs, k, 'dung', p);
p.ghiChu = 'Đỉnh 1 bị xén ở 0.5, sinh hài và tích chập tần';
x = dtmf_generate(k, 'ampl', 1);
n = n + 1;  rows(n, :) = ghi(outDir, 'dinh_dang/xen_dinh.wav', max(min(x, 0.5), -0.5), fs, k, 'thong_ke', p);

%% 2.10 khong_phim - âm thanh không có phím nào, mọi bộ giải mã phải im lặng
rng(10);
p = mau('khong_phim');
p.toneMs = NaN;  p.nghiMs = NaN;
am = {
    'im_lang.wav',             zeros(1, fs),                            'Toàn số 0, năng lượng khung bằng 0'
    'nen_on_-60dBFS.wav',      1e-3 * randn(1, 2*fs),                   'Nhiễu nền rất nhỏ'
    'nhieu_trang.wav',         0.1 * randn(1, 2*fs),                    'Nhiễu trắng'
    'u_50Hz.wav',              0.5 * tone(50, 2000, fs),                'Điện lưới 50 Hz'
    'mot_tan_697.wav',         tone(697, 1000, fs),                     'Chỉ một tone nhóm hàng'
    'mot_tan_1336.wav',        tone(1336, 1000, fs),                    'Chỉ một tone nhóm cột'
    'hai_tan_cung_nhom.wav',   tone([697 852], 1000, fs),               'Hai tone cùng nhóm hàng'
    'phim_A_697_1633.wav',     lapLai(tone([697 1633], 100, fs), 50, 4, fs), 'Phím A của bàn phím 16 phím, ngoài 12 phím dự án hỗ trợ'
    'moi_quay_so_425.wav',     tone(425, 2000, fs),                     'Âm mời quay số'
    'bao_ban_425.wav',         lapLai(tone(425, 500, fs), 500, 3, fs),  'Âm báo bận'
    'moi_quay_so_350_440.wav', tone([350 440], 2000, fs),               'Âm mời quay số kiểu Bắc Mỹ, hai tần số'
    'quet_tan_300_3400.wav',   quetTan(300, 3400, 2, fs),               'Quét tần 300-3400 Hz đi qua cả bảy tần số DTMF'
    'tieng_noi_nen_on.wav',    s(8*fs+1:11.5*fs) + 1e-3*randn(1, 3.5*fs), 'Đoạn 8-11.5 s của speech_tong_dai.wav cộng nền -60 dBFS, có nền là hết phím giả do dao động dư (§7.13)'
    };
for i = 1:size(am, 1)
    p.ghiChu = am{i, 3};
    n = n + 1;  rows(n, :) = ghi(outDir, ['khong_phim/' am{i, 1}], am{i, 2}, fs, '', 'rong', p);
end

%% 4. Bảng nhãn
M = cell2table(rows(1:n, :), 'VariableNames', {'tep', 'nhom', 'phim', 'kyVong', ...
    'ngoaiLe', 'fs', 'kenh', 'bit', 'nhieu', 'snrDb', 'twistDb', 'lechPct', ...
    'toneMs', 'nghiMs', 'ghiChu'});
writetable(M, fullfile(outDir, 'manifest.csv'), 'Encoding', 'UTF-8', 'QuoteStrings', 'all');

fprintf('Da ghi %d tep vao %s\n', height(M), outDir);
end


%% ---------------------------------------------------------------- hàm phụ

function p = mau(nhom)
% Thông số mặc định của một dòng nhãn: nhịp chuẩn 100/50 ms, không nhiễu.
p = struct('nhom', nhom, 'ngoaiLe', '', 'nhieu', 'khong', 'snrDb', NaN, ...
           'twistDb', 0, 'lechPct', 0, 'toneMs', 100, 'nghiMs', 50, 'ghiChu', '');
end

function row = ghi(outDir, tep, y, fsTep, phim, kyVong, p, bit)
% Ghi một tệp (y là 1×N hoặc N×C) và trả về dòng nhãn của nó.
if nargin < 8
    bit = 16;
end
if isrow(y)
    y = y(:);
end
pk = max(abs(y(:)));
if pk > 0.95
    y = y * (0.95 / pk);
end
f = fullfile(outDir, tep);
if ~isfolder(fileparts(f))
    mkdir(fileparts(f));
end
audiowrite(f, y, fsTep, 'BitsPerSample', bit);
row = {tep, p.nhom, phim, kyVong, p.ngoaiLe, fsTep, size(y, 2), bit, p.nhieu, ...
       p.snrDb, p.twistDb, p.lechPct, p.toneMs, p.nghiMs, p.ghiChu};
end

function kv = kyVongSnr(snr, snrMin)
% Từ snrMin trở lên là mức demo mà dự án cam kết đọc đúng (CONTRACTS §7.2).
if snr >= snrMin
    kv = 'dung';
else
    kv = 'thong_ke';
end
end

function so = soDienThoai()
% Số di động mười chữ số, bắt đầu bằng 0.
so = ['0', char('0' + randi([0 9], 1, 9))];
end

function c = chuoiNgauNhien(allKeys, n)
% n chuỗi 12 phím rút từ đủ 12 phím, như run_bench.
c = cell(1, n);
for i = 1:n
    c{i} = allKeys(randi(numel(allKeys), 1, 12));
end
end

function x = bamTheoNhip(keys, R, fs)
% Người bấm tay: mở đầu im lặng, mỗi phím dài ngắn, to nhỏ, twist khác nhau
% một chút, số từ tám chữ số trở lên ngắt nhóm 4-3-3 như 0912 345 678.
uni   = @(r) r(1) + (r(2) - r(1)) * rand();
phan  = cell(1, 2*numel(keys) + 1);
phan{1} = zeros(1, round(uni(R.lead) * fs));
for i = 1:numel(keys)
    nghi = 0;
    if i > 1
        nghi = uni(R.gap);
        if ~isempty(R.group) && numel(keys) >= 8 && (i == 5 || i == 8)
            nghi = nghi + uni(R.group);
        end
    end
    g  = 10^((2*rand() - 1) * R.jitterDb / 20);
    tw = (2*rand() - 1) * R.jitterDb;
    phan{2*i}   = zeros(1, round(nghi / 1000 * fs));
    phan{2*i+1} = dtmf_generate(keys(i), 'toneMs', uni(R.tone), 'twistDb', tw, ...
                                'ampl', 0.5 * g, 'fs', fs);
end
x = [phan{:}, zeros(1, round(0.8 * fs))];
end

function s = moTaNhip(R)
% Mô tả nhịp bằng chữ cho cột ghiChu.
s = sprintf('tone %d-%d ms, nghỉ %d-%d ms', R.tone, R.gap);
if ~isempty(R.group)
    s = [s, sprintf(', ngắt nhóm 4-3-3 thêm %d-%d ms', R.group)];
end
end

function y = tronHienTruong(x, s, bgDb, snrDb)
% Trộn tiếng nói (một đoạn bắt đầu ngẫu nhiên trong s, lặp vòng nếu thiếu) và
% nhiễu trắng vào x. Mức của cả hai so với công suất trên các mẫu có tone.
Pt = mean(x(x ~= 0).^2);
y  = x;
if ~isnan(bgDb)
    idx = mod(randi(numel(s)) + (0:numel(x)-1) - 1, numel(s)) + 1;
    v = s(idx);
    y = y + v * sqrt(Pt * 10^(bgDb/10) / mean(v.^2));
end
if ~isnan(snrDb)
    y = y + randn(size(x)) * sqrt(Pt / 10^(snrDb/10));
end
end

function x = tone(f, ms, fs)
% Tổng các sin tần số f (vector) dài ms, côn Tukey 5% như dtmf_generate, đỉnh 0.5.
t = (0:round(ms/1000*fs) - 1) / fs;
x = sum(sin(2*pi*f(:)*t), 1) .* tukeywin(numel(t), 0.05).';
x = x * (0.5 / max(abs(x)));
end

function x = lapLai(seg, nghiMs, n, fs)
% n lần seg, xen khoảng lặng nghiMs.
lang = zeros(1, round(nghiMs/1000*fs));
x = [repmat([seg, lang], 1, n-1), seg];
end

function x = quetTan(f0, f1, sec, fs)
% Quét tần tuyến tính f0 -> f1 trong sec giây, đỉnh 0.5.
t = (0:round(sec*fs) - 1) / fs;
x = 0.5 * sin(2*pi*(f0*t + (f1 - f0) * t.^2 / (2*sec)));
end
