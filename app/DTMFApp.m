classdef DTMFApp < handle
%DTMFAPP Giao diện phát và giải mã DTMF theo ba bước: tín hiệu gốc, kênh nhiễu, giải mã
% Đi đúng đường tín hiệu đi: tạo x[n] rồi xem phổ, cộng nhiễu thành y[n] rồi xem phổ, sau cùng mới tìm phím
%   APP = DTMFAPP() mở giao diện. APP = DTMFAPP('off') dựng giao diện ẩn để
%   chạy tự động trong matlab -batch; lúc ẩn thì không phát ra tiếng.
%
%   Bố cục: dòng tiêu đề kèm chọn nguồn, ba thẻ bước xếp dọc, thanh trạng
%   thái. Mỗi thẻ bước gồm cột điều khiển bên trái và hai trục bên phải -
%   miền thời gian rồi miền tần số - của ĐÚNG tín hiệu ở bước đó:
%       Bước 1  Tín hiệu gốc   bàn phím, nút Tạo tín hiệu  ->  x[n] và phổ của x[n]
%       Bước 2  Kênh nhiễu     loại nhiễu, SNR, nút Cộng nhiễu  ->  y[n] và phổ
%                              y[n] chồng phổ x[n]
%       Bước 3  Giải mã        bộ giải mã, nút Giải mã  ->  năng lượng 8 bin theo khung,
%                        khung quyết định, chuỗi phím đọc được
%
%   Các bước hoạt động:
%       1. Constructor dựng struct trạng thái S mặc định, dựng toàn bộ
%          component theo docs/ui_naming.md, rồi vẽ một lần để sáu trục có
%          tiêu đề hướng dẫn ngay khi cửa sổ hiện lên.
%       2. Mỗi callback làm đúng ba việc: đọc UI vào S, gọi lớp tính toán
%          (taoTinHieu, congNhieu hoặc dtmf_run), rồi veLai(app).
%       3. Không một phép tính DSP nào nằm trong callback - luật CONTRACTS §2
%          và §6(h). Callback chỉ điều phối.
%       4. Đổi tham số của một bước ĐÃ làm thì chạy lại bước đó và các bước đã
%          làm sau nó: kéo SNR sau khi đã cộng nhiễu thì cộng lại nhiễu vào
%          cùng x[n], rồi giải mã lại nếu đã giải mã. Bước CHƯA làm thì chỉ ghi
%          nhận tham số - không bước nào tự chạy khi người dùng chưa bấm nút.
%       5. Nguồn micro: bước 1 là thu âm ("Giải mã trực tiếp" đưa từng đoạn
%          micro qua dtmf_listen; "Ghi âm rồi giải mã" thu tới khi bấm lần nữa
%          rồi giải mã cả bản ghi bằng dtmf_run). Bản ghi chính là y[n] ở bước
%          2, và bước 2 không cộng thêm nhiễu vì bản ghi đã mang nhiễu thật.
%          Chạy ẩn thì không mở micro - test đưa mẫu vào qua nhanMauMic và
%          napBanGhi.
%       6. Nhập từ tệp: nút "Mở tệp âm thanh" ở bước 1 đọc tệp qua
%          dtmf_readaudio (một kênh, 8 kHz) và dùng nó làm x[n]; bước 2 và 3
%          đi như tín hiệu tổng hợp, chỉ là không có chuỗi đã phát để so
%          đúng/sai. Test gọi thẳng napTep, vì chạy ẩn thì không mở hộp chọn tệp.
%
%   Input:
%       visible: 'on' (mặc định) hoặc 'off'. Ẩn dùng cho unit test và cho
%                việc chụp hình bằng exportgraphics.
%
%   Output:
%       app: đối tượng DTMFApp; delete(app) đóng cửa sổ.
%
%   Example:
%       app = DTMFApp('off');
%       app.EfKeys.Value = '0912345';
%       app.BtnGenPushed([]);       % bước 1: x[n]
%       app.BtnNoisePushed([]);     % bước 2: y[n] = x[n] + v[n]
%       app.BtnDecodePushed([]);    % bước 3: giải mã y[n]
%       app.LblDecoded.Text         % '0912345'

    properties (Access = public)
        UIFigure    matlab.ui.Figure

        % Nguồn tín hiệu: hai nút dạng tab ở dòng tiêu đề. PnlKeypad và PnlMic
        % là phần điều khiển của bước 1 cho hai nguồn, chồng lên nhau ở cùng
        % một ô lưới - chỉ một cái hiện.
        BtnSrcGen   matlab.ui.control.Button
        BtnSrcMic   matlab.ui.control.Button
        PnlKeypad   matlab.ui.container.Panel
        PnlMic      matlab.ui.container.Panel

        % Bàn phím. Thứ người dùng thấy và bấm là AxKeypad - bàn phím phẳng
        % vẽ bằng ui_pad; bấm một phím là gọi Btn1Pushed với đúng nút ở
        % dưới đây. 12 nút giữ nguyên (ẩn) vì tên đóng băng theo
        % docs/ui_naming.md §2 và test gọi thẳng chúng: '*' và '#' không hợp
        % lệ trong tên biến MATLAB nên viết chữ, còn Text vẫn là ký tự thật.
        AxKeypad    matlab.ui.control.UIAxes
        Btn1        matlab.ui.control.Button
        Btn2        matlab.ui.control.Button
        Btn3        matlab.ui.control.Button
        Btn4        matlab.ui.control.Button
        Btn5        matlab.ui.control.Button
        Btn6        matlab.ui.control.Button
        Btn7        matlab.ui.control.Button
        Btn8        matlab.ui.control.Button
        Btn9        matlab.ui.control.Button
        BtnStar     matlab.ui.control.Button
        Btn0        matlab.ui.control.Button
        BtnHash     matlab.ui.control.Button

        % Sáu trục, hai trục mỗi bước - xem ui_refresh.
        AxWaveX     matlab.ui.control.UIAxes
        AxPsdX      matlab.ui.control.UIAxes
        AxWave      matlab.ui.control.UIAxes
        AxPsd       matlab.ui.control.UIAxes
        AxMap       matlab.ui.control.UIAxes
        AxBars      matlab.ui.control.UIAxes

        % Bước 1
        EfKeys      matlab.ui.control.EditField
        BtnClear    matlab.ui.control.Button
        BtnGen      matlab.ui.control.Button
        BtnPlayX    matlab.ui.control.Button
        BtnOpen     matlab.ui.control.Button
        BtnRecord   matlab.ui.control.Button
        BtnListen   matlab.ui.control.Button

        % Bước 2
        DdNoise     matlab.ui.control.DropDown
        SldSNR      matlab.ui.control.Slider
        LblSNR      matlab.ui.control.Label
        BtnNoise    matlab.ui.control.Button
        BtnPlay     matlab.ui.control.Button

        % Bước 3
        DdMethod    matlab.ui.control.DropDown
        BtnDecode   matlab.ui.control.Button
        LblSent     matlab.ui.control.Label
        LblDecoded  matlab.ui.control.Label

        % Thanh trạng thái
        LblStatus   matlab.ui.control.Label
        TxtLog      matlab.ui.control.TextArea

        % Một property trạng thái DUY NHẤT, không rải biến rời rạc. Danh sách
        % trường: docs/ui_naming.md §5.
        S           struct
    end

    properties (Access = private)
        % Tín hiệu hiện tại đã qua bộ giải mã chưa. Không suy được từ S: sau
        % "Cộng nhiễu" và sau một lần giải mã không ra phím nào, S.keysHat
        % cùng rỗng - nhưng dòng trạng thái phải nói hai điều khác nhau.
        DaGiaiMa    logical = false

        % Micro. CheDoMic: '' (tắt) | 'ghi' (ghi âm rồi giải mã) | 'nghe' (giải
        % mã trực tiếp). Mic là audiorecorder, rỗng khi tắt hoặc khi chạy ẩn.
        Mic
        CheDoMic    char = ''
        DaDoc       double = 0      % số mẫu đã lấy khỏi Mic từ lúc record()
        MocVe                       % tic của lần vẽ gần nhất trong chế độ micro

        % S.y hiện tại đến từ micro chứ không phải dtmf_addnoise: không có x
        % để cộng lại nhiễu, không có chuỗi đã phát để so.
        NguonMic    logical = false

        % Tên tệp (không kèm thư mục) khi x[n] được nạp từ tệp âm thanh; rỗng
        % khi x[n] sinh từ chuỗi phím. Tệp không có chuỗi đã phát để so.
        TepAm       char = ''

        % Trạng thái bộ giải mã luồng - xem app/dtmf_listen.m. TuLuong: kết quả
        % đang hiện là của L (nghe trực tiếp), chứ không phải của dtmf_run.
        % Cần vì S.keysHat khi đó chỉ giữ 12 phím cuối, còn dòng trạng thái
        % phải báo tổng số phím đã nghe được.
        L           struct
        TuLuong     logical = false

        % Ba thẻ bước: viền thẻ, số bước ở góc, dòng thông tin bên phải. Viền
        % thẻ của bước cần làm tiếp tô màu nhấn; số bước tô màu nhấn khi bước
        % đó đã có kết quả.
        TheBuoc
        LblSo
        LblInfo

        % Bàn phím vẽ: đối tượng đồ họa của ui_pad, và đồng hồ tắt đèn
        % ô vừa bấm sau SANG_PHIM giây.
        Ban
        NhipPhim
    end

    properties (Constant, Access = private)
        % Chu kỳ tick của micro [s]: 50 ms = 400 mẫu, gần hai khung Goertzel.
        CHU_KY_MIC = 0.05
        % Chu kỳ vẽ lại các trục khi nghe trực tiếp [s]. Một lần ui_refresh tốn
        % ~0.4 s (đo 29/09/2026, giao diện hiện), vẽ theo từng tick thì giao
        % diện đứng hình; phím mới vẫn hiện ngay vì chỉ đổi một nhãn (~20 ms).
        CHU_KY_VE  = 1.0
        % Ghi âm tự dừng sau chừng này giây [s].
        GHI_TOI_DA = 20
        % Nghe quá chừng này giây thì ghi lại từ đầu [s], vì getaudiodata trả
        % CẢ bản ghi nên mỗi tick chậm dần theo độ dài bản ghi.
        NGHE_TOI_DA = 120
        % Ô vừa bấm trên bàn phím sáng trong chừng này giây [s].
        SANG_PHIM = 0.25
        % Tệp âm thanh dài hơn chừng này giây thì chỉ lấy phần đầu [s].
        TEP_TOI_DA = 60
    end

    methods (Access = public)

        function app = DTMFApp(visible)
        %DTMFAPP Dựng giao diện và vẽ trạng thái rỗng ban đầu.
            if nargin < 1
                visible = 'on';
            end

            app.S = struct('keys',      blanks(0), ...
                           'x',         zeros(1, 0), ...
                           'y',         zeros(1, 0), ...
                           'fs',        8000, ...
                           'meta',      [], ...
                           'noise',     'awgn', ...
                           'snrDb',     20, ...
                           'method',    'goertzel', ...
                           'keysHat',   blanks(0), ...
                           'info',      struct('E', zeros(8, 0)), ...
                           'thr',       0, ...
                           'iSel',      0, ...
                           'lastError', blanks(0));

            dungGiaoDien(app, visible);

            % Vẽ ngay để sáu trục có tiêu đề hướng dẫn thay vì sáu ô trắng
            % không rõ là đang hỏng hay đang chờ.
            veLai(app);
        end

        function delete(app)
        %DELETE Tắt micro rồi đóng cửa sổ khi đối tượng bị hủy.
        % Tắt micro TRƯỚC: tick của nó còn chạy sau khi app bị hủy thì mỗi
        % 50 ms lại ném một lỗi ra cửa sổ lệnh.
            tatMic(app);
            if ~isempty(app.NhipPhim) && isvalid(app.NhipPhim)
                stop(app.NhipPhim);
                delete(app.NhipPhim);
            end
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end

        % ------------------------------------------------------------ callback
        %
        % Mọi callback dưới đây để PUBLIC, khác App Designer (mặc định
        % private), vì unit test gọi thẳng chúng: không có API công khai nào
        % để "bấm" một uibutton bằng code.

        function BtnSrcPushed(app, event)
        %BTNSRCPUSHED Callback dùng chung cho hai nút nguồn: tổng hợp / micro.
        % Bấm lại nút nguồn đang chọn thì không làm gì - không xóa kết quả.
            mic = event.Source == app.BtnSrcMic;
            if mic ~= app.NguonMic && isempty(app.CheDoMic)
                doiNguon(app, mic);
            end
        end

        % --- bước 1

        function Btn1Pushed(app, event)
        %BTN1PUSHED Callback dùng chung cho cả 12 nút bàn phím.
            app.EfKeys.Value = [app.EfKeys.Value, event.Source.Text];
            capNhatNut(app);
            sangPhim(app, event.Source.Text);
            phatPhim(app, event.Source.Text);
        end

        function AxKeypadClicked(app, event)
        %AXKEYPADCLICKED Bấm vào một phím của bàn phím vẽ: tra phím theo tọa độ
        % rồi đi đúng đường của nút tương ứng (Btn1Pushed).
            p = event.IntersectionPoint;
            c = round(p(1));
            r = round(p(2));
            if r < 1 || r > 4 || c < 1 || c > 3
                return
            end
            ten = {'Btn1', 'Btn2', 'Btn3', 'Btn4', 'Btn5', 'Btn6', ...
                   'Btn7', 'Btn8', 'Btn9', 'BtnStar', 'Btn0', 'BtnHash'};
            app.Btn1Pushed(struct('Source', app.(ten{(r - 1) * 3 + c})));
        end

        function EfKeysValueChanging(app, event)
        %EFKEYSVALUECHANGING Gõ phím thì tô lại nút: chuỗi đã khác lần tạo
        % trước nghĩa là bước tiếp theo lại là Tạo tín hiệu.
            capNhatNut(app, event.Value);
        end

        function BtnClearPushed(app, ~)
        %BTNCLEARPUSHED Xóa trắng ô chuỗi phím, không đụng tín hiệu đang có.
            app.EfKeys.Value = '';
            capNhatNut(app);
        end

        function BtnGenPushed(app, ~)
        %BTNGENPUSHED Bước 1: dựng x[n] từ chuỗi phím. Chưa cộng nhiễu, chưa giải mã.
            docUI(app);
            taoTinHieu(app);
            veLai(app);
        end

        function BtnPlayXPushed(app, ~)
        %BTNPLAYXPUSHED Phát x[n] - tín hiệu gốc, chưa có nhiễu.
            phat(app, app.S.x);
        end

        function BtnOpenPushed(app, ~)
        %BTNOPENPUSHED Chọn một tệp âm thanh rồi nạp làm x[n] - xem napTep.
            [ten, thuMuc] = uigetfile( ...
                {'*.wav;*.flac;*.ogg;*.mp3;*.m4a', 'Tệp âm thanh (wav, flac, ogg, mp3, m4a)'}, ...
                'Chọn tệp âm thanh DTMF');
            % Hộp chọn tệp kéo tiêu điểm đi; trả lại cho cửa sổ app.
            figure(app.UIFigure);
            if isequal(ten, 0)
                return
            end
            napTep(app, fullfile(thuMuc, ten));
        end

        % --- bước 2

        function BtnNoisePushed(app, ~)
        %BTNNOISEPUSHED Bước 2: y[n] = x[n] + v[n] theo loại nhiễu và SNR đang chọn.
            docUI(app);
            congNhieu(app);
            veLai(app);
        end

        function BtnPlayPushed(app, ~)
        %BTNPLAYPUSHED Phát y[n] - tín hiệu ĐÃ CỘNG NHIỄU, đúng cái bộ giải mã nghe.
            phat(app, app.S.y);
        end

        function SldSNRValueChanging(app, event)
        %SLDSNRVALUECHANGING Chỉ cập nhật nhãn số dB trong lúc đang kéo.
        % KHÔNG cộng nhiễu ở đây: làm lại sau mỗi pixel kéo chuột thì giao
        % diện giật - việc đó để cho SldSNRValueChanged lúc thả chuột.
            hienSNR(app, event.Value);
        end

        function SldSNRValueChanged(app, ~)
        %SLDSNRVALUECHANGED Đổi SNR: nếu đã cộng nhiễu thì cộng lại và chạy lại các bước sau.
            hienSNR(app, app.SldSNR.Value);
            doiKenh(app);
        end

        function DdNoiseValueChanged(app, ~)
        %DDNOISEVALUECHANGED Đổi loại nhiễu: như đổi SNR.
            doiKenh(app);
        end

        % --- bước 3

        function BtnDecodePushed(app, ~)
        %BTNDECODEPUSHED Bước 3: giải mã y[n] bằng bộ giải mã đang chọn.
            docUI(app);
            giaiMa(app);
            veLai(app);
        end

        function DdMethodValueChanged(app, ~)
        %DDMETHODVALUECHANGED Đổi bộ giải mã: đã giải mã rồi thì giải mã lại ngay.
        % Chưa giải mã thì chỉ ghi nhận lựa chọn - bước 3 đợi người dùng bấm.
        % Đang dùng micro thì không có tín hiệu cố định để giải mã lại - xem
        % doiPhuongPhapMic.
            if ~isempty(app.CheDoMic)
                doiPhuongPhapMic(app);
            elseif app.DaGiaiMa && ~isempty(app.S.y)
                BtnDecodePushed(app, []);
            else
                docUI(app);
                capNhatKetQua(app);
                capNhatNut(app);
            end
        end

        % --- micro

        function BtnRecordPushed(app, ~)
        %BTNRECORDPUSHED Bấm lần đầu thì ghi âm micro, bấm lần nữa thì dừng và giải mã.
            switch app.CheDoMic
                case ''
                    batDauGhi(app);
                case 'ghi'
                    dungGhi(app);
            end
        end

        function BtnListenPushed(app, ~)
        %BTNLISTENPUSHED Bật / tắt chế độ nghe micro và hiện phím ngay khi nhận ra.
            switch app.CheDoMic
                case ''
                    batDauNghe(app);
                case 'nghe'
                    dungNghe(app);
            end
        end

        % ---------------------------------------------------- lối vào micro
        %
        % Hai method PUBLIC dưới đây là chỗ âm thanh micro đi vào app. Tick
        % của micro và nút dừng ghi gọi chúng; test gọi thẳng với tín hiệu
        % tổng hợp, vì chạy ẩn thì app không mở micro.

        function nhanMauMic(app, chunk)
        %NHANMAUMIC Đưa một đoạn mẫu micro vào bộ giải mã luồng rồi hiển thị.
        % Có phím mới thì chỉ đổi nhãn kết quả (~20 ms) để phím hiện ngay; các
        % trục vẽ lại tối đa mỗi CHU_KY_VE giây một lần.
            if ~strcmp(app.CheDoMic, 'nghe')
                return
            end

            app.L = dtmf_listen(app.L, chunk);
            if ~isempty(app.L.lastError)
                ghiNhatKy(app, app.L.lastError);
            end

            if isempty(app.MocVe) || toc(app.MocVe) >= app.CHU_KY_VE
                veNghe(app, true);
            elseif ~isempty(app.L.newKeys)
                veNghe(app, false);
            end
        end

        function napBanGhi(app, y)
        %NAPBANGHI Lấy một đoạn âm thanh thu từ micro làm y[n] rồi giải mã.
            docUI(app);
            xoaKetQua(app);
            app.S.lastError = blanks(0);
            app.S.x    = zeros(1, 0);
            app.S.y    = reshape(double(y), 1, []);
            app.S.meta = [];
            app.NguonMic = true;

            % Bản ghi rỗng (bấm dừng ngay, hay chạy ẩn) thì không có gì để giải
            % mã; dòng trạng thái tự báo "chưa có tín hiệu".
            if ~isempty(app.S.y)
                giaiMa(app);
            end
            veLai(app);
        end

        function napTep(app, duongDan)
        %NAPTEP Đọc một tệp âm thanh làm x[n], xóa y[n] và kết quả cũ.
        % Đọc và đổi tần số lấy mẫu nằm ở dtmf_readaudio, không ở đây. Tệp
        % hỏng hay sai định dạng là chuyện thường ngày nên chỉ ghi lỗi, như ký
        % tự lạ trong ô phím.
            docUI(app);
            xoaKetQua(app);
            app.S.lastError = blanks(0);
            app.S.y    = zeros(1, 0);
            app.S.meta = [];
            app.TuLuong = false;
            [~, ten, duoi] = fileparts(char(duongDan));
            try
                [x, info] = dtmf_readaudio(duongDan, 'fs', app.S.fs, ...
                    'maxSec', app.TEP_TOI_DA);
                app.S.x   = x;
                app.TepAm = [ten, duoi];
                % Tên tệp và độ dài đã hiện ở dòng thông tin bước 1; nhật ký chỉ
                % dành cho lỗi và cảnh báo.
                if info.truncated
                    ghiNhatKy(app, sprintf('Tệp dài %.0f s, chỉ lấy %d s đầu.', ...
                        info.fileSec, app.TEP_TOI_DA));
                end
            catch ME
                app.S.x   = zeros(1, 0);
                app.TepAm = '';
                app.S.lastError = sprintf('Không đọc được tệp %s: %s', [ten, duoi], ME.message);
            end
            veLai(app);
        end

    end

    methods (Access = private)

        function docUI(app)
        %DOCUI Chép giá trị các ô điều khiển vào S. Đây là chiều UI -> S duy nhất.
        % reshape(..., 1, []) giữ luật CONTRACTS §2 "mọi giá trị rỗng là 1×0":
        % ô phím vừa bị xóa trắng trả về '' tức 0×0. dtmf_generate nhận cả hai
        % cỡ nên đây KHÔNG phải chốt chặn lỗi, nhưng S.keys đi thẳng sang
        % meta.keys rồi tới các phép so chuỗi bằng isequal, mà isequal phân
        % biệt 0×0 với 1×0 - chuẩn hóa ngay ở cửa vào là rẻ nhất.
            app.S.keys   = reshape(char(app.EfKeys.Value), 1, []);
            app.S.noise  = app.DdNoise.Value;
            app.S.snrDb  = app.SldSNR.Value;
            app.S.method = app.DdMethod.Value;

            % Thanh trượt có thể bị đặt bằng code (test, make_figures) mà
            % không qua ValueChanging - nhãn dB phải khớp giá trị thật.
            hienSNR(app, app.S.snrDb);
        end

        function taoTinHieu(app)
        %TAOTINHIEU Bước 1: dựng x từ S.keys. Xóa y và kết quả cũ - chúng thuộc x cũ.
            xoaKetQua(app);
            app.S.lastError = blanks(0);
            app.NguonMic = false;
            app.TepAm = '';
            app.S.y = zeros(1, 0);

            try
                [app.S.x, ~, app.S.meta] = dtmf_generate(app.S.keys, 'fs', app.S.fs);
            catch ME
                % Ký tự lạ trong ô phím là chuyện thường ngày, không phải sự
                % cố. Xóa luôn tín hiệu cũ: giữ lại thì màn hình vẽ một dạng
                % sóng KHÔNG khớp chuỗi phím đang hiện, gây hiểu nhầm nặng.
                app.S.x    = zeros(1, 0);
                app.S.meta = [];
                app.S.lastError = ME.message;
            end
        end

        function ok = congNhieu(app)
        %CONGNHIEU Bước 2: dựng y từ x theo S.noise và S.snrDb, giữ nguyên x và meta.
        % Đổi SNR chỉ gọi lại hàm này, không sinh lại x: giữ tính "cùng một tín
        % hiệu gốc, chỉ khác mức nhiễu" của phần demo.
            xoaKetQua(app);
            app.S.lastError = blanks(0);

            try
                app.S.y = dtmf_addnoise(app.S.x, 'snrDb', app.S.snrDb, ...
                    'type', app.S.noise, 'fs', app.S.fs);
                ok = true;
            catch ME
                app.S.y = zeros(1, 0);
                app.S.lastError = ME.message;
                ok = false;
            end
        end

        function doiKenh(app)
        %DOIKENH Tham số kênh vừa đổi: cộng lại nhiễu, giải mã lại nếu đã giải mã.
        % Micro: không có x để cộng lại nhiễu - đi tiếp thì congNhieu thay bản
        % ghi bằng một tín hiệu rỗng. Chưa cộng nhiễu: bước 2 chưa làm thì chỉ
        % ghi nhận tham số, đợi người dùng bấm Cộng nhiễu.
            docUI(app);
            if app.NguonMic || isempty(app.S.y)
                capNhatKetQua(app);
                return
            end

            daGiai = app.DaGiaiMa;
            if congNhieu(app) && daGiai
                giaiMa(app);
            end
            veLai(app);
        end

        function xoaKetQua(app)
        %XOAKETQUA Xóa kết quả giải mã cũ khi tín hiệu vừa đổi.
        % KHÔNG đụng S.info: ui_refresh chỉ đọc info khi iSel >= 1, nên đặt
        % iSel = 0 là đủ xóa sạch màn hình mà không phải chép lại hình dạng
        % rỗng của info - chép lại là sớm muộn lệch với dtmf_run Bước 1.
        % Cũng KHÔNG đụng S.lastError: lỗi do người gọi quản lý.
            app.S.keysHat = blanks(0);
            app.S.iSel    = 0;
            app.S.thr     = 0;
            app.DaGiaiMa  = false;
        end

        function giaiMa(app)
        %GIAIMA Bước 3: chạy dtmf_run và ghi nhận là tín hiệu hiện tại đã được giải mã.
            app.S = dtmf_run(app.S);
            app.DaGiaiMa = true;
            app.TuLuong  = false;
        end

        function veLai(app)
        %VELAI Vẽ lại sáu trục qua ui_refresh, rồi tiêu đề, kết quả và nút.
        % Tiêu đề trục, nhãn kết quả và dòng trạng thái nằm NGOÀI ui_refresh
        % vì chúng phụ thuộc trạng thái của app (nguồn, bước đã làm) mà hợp
        % đồng của ui_refresh không có - CONTRACTS §8.
            ui_refresh(app);
            datTieuDe(app);
            capNhatKetQua(app);
            capNhatNut(app);
        end

        function datTieuDe(app)
        %DATTIEUDE Tiêu đề sáu trục: có nội dung thì nói đây là tín hiệu nào, trống
        % thì nói phải bấm gì để có. ui_plot_* đặt tiêu đề chung chung vì chúng
        % không biết mình đang vẽ x[n] hay y[n].
            S   = app.S;
            mic = app.NguonMic;
            coX = ~isempty(S.x);
            coY = ~isempty(S.y);

            % Bước 1
            if mic
                tieuDe(app.AxWaveX, 'Nguồn micro: x[n] nằm ở thiết bị phát, không thu được');
                tieuDe(app.AxPsdX,  'Không có x[n]');
            elseif coX && ~isempty(app.TepAm)
                tieuDe(app.AxWaveX, 'Dạng sóng x[n] nạp từ tệp');
                tieuDe(app.AxPsdX,  'Phổ công suất của x[n]');
            elseif coX
                tieuDe(app.AxWaveX, 'Dạng sóng x[n]');
                tieuDe(app.AxPsdX,  'Phổ công suất của x[n]');
            else
                tieuDe(app.AxWaveX, 'Chưa có x[n]   ·   gõ chuỗi phím rồi bấm Tạo tín hiệu, hoặc mở tệp');
                tieuDe(app.AxPsdX,  'Chưa có x[n]');
            end

            % Bước 2
            if coY && mic
                tieuDe(app.AxWave, 'Dạng sóng y[n] thu từ micro');
                tieuDe(app.AxPsd,  'Phổ công suất của y[n]');
            elseif coY
                tieuDe(app.AxWave, 'Dạng sóng y[n] = x[n] + v[n]');
                tieuDe(app.AxPsd,  'Phổ công suất của y[n], nét xám là x[n]');
            elseif mic
                tieuDe(app.AxWave, 'Chưa thu   ·   chọn một cách thu ở bước 1');
                tieuDe(app.AxPsd,  'Chưa có y[n]');
            elseif coX
                tieuDe(app.AxWave, 'Chưa có y[n]   ·   chọn nhiễu, SNR rồi bấm Cộng nhiễu');
                tieuDe(app.AxPsd,  'Chưa có y[n]');
            else
                tieuDe(app.AxWave, 'Chưa có y[n]');
                tieuDe(app.AxPsd,  'Chưa có y[n]');
            end

            % Bước 3 - có khung thì giữ tiêu đề của ui_plot_map / ui_plot_bars, vì
            % chúng mang số liệu (số khung, ngưỡng).
            if S.iSel < 1
                if coY
                    tieuDe(app.AxMap,  'Chưa giải mã   ·   chọn bộ giải mã rồi bấm Giải mã');
                else
                    tieuDe(app.AxMap,  'Chưa có tín hiệu để giải mã');
                end
                tieuDe(app.AxBars, 'Chưa có khung nào');
            end

            % Đánh số như chú thích hình của LaTeX: "Hình k:" đậm đứng đầu.
            % Tiêu đề dùng bộ diễn dịch tex mặc định, nên \bf ... \rm bật tắt
            % chữ đậm; tiêu đề đã đánh số (của lần vẽ trước) thì không đánh lại.
            % Ghép chuỗi chứ không sprintf: với sprintf, \b là ký tự lùi.
            ax = [app.AxWaveX, app.AxPsdX, app.AxWave, app.AxPsd, app.AxMap, app.AxBars];
            for k = 1:numel(ax)
                t = char(ax(k).Title.String);
                if ~startsWith(t, '\bfHình')
                    ax(k).Title.String = ['\bfHình ' num2str(k) ':\rm ' t];
                end
            end
        end

        function capNhatKetQua(app)
        %CAPNHATKETQUA Ghi chuỗi đã phát, dòng trạng thái và dòng thông tin mỗi bước.
        % Chỉ so chuỗi và đếm nhãn - không phép tính DSP nào, luật §2.
            M = ui_theme();
            S = app.S;

            daPhat = blanks(0);
            if isstruct(S.meta) && isfield(S.meta, 'keys')
                daPhat = S.meta.keys;
            end
            app.LblSent.Text = daPhat;

            tenPP = tenMuc(app.DdMethod, S.method);
            tenNh = tenNhieu(S.noise);
            boi = sprintf('%s   ·   %s, SNR %.0f dB', tenPP, tenNh, S.snrDb);

            % Chấm đặc = đã có kết luận (đúng/sai), chấm rỗng = đang chờ một
            % bước - kèm việc cần làm tiếp, cùng ý với viền thẻ và màu nút.
            if ~isempty(S.lastError)
                txt = '●  Có lỗi, xem nhật ký bên phải';
                mau = M.sai;
            elseif app.NguonMic
                app.LblSent.Text = '(micro)';
                [txt, mau] = trangThaiMic(app, tenPP, M);
            elseif isempty(S.x)
                txt = '○  Bước 1   ·   gõ chuỗi phím rồi bấm Tạo tín hiệu, hoặc mở tệp âm thanh';
                mau = M.chuMo;
            elseif ~isempty(app.TepAm)
                app.LblSent.Text = '(tệp)';
                [txt, mau] = trangThaiTep(app, tenNh, boi, M);
            elseif isempty(S.y)
                txt = sprintf(['○  Đã tạo x[n] gồm %d phím   ·   bước 2   ·   chọn ' ...
                    'loại nhiễu, SNR rồi bấm Cộng nhiễu'], numel(daPhat));
                mau = M.chuPhu;
            elseif ~app.DaGiaiMa
                txt = sprintf(['○  Đã cộng nhiễu %s, SNR %.0f dB   ·   bước 3   ·   ' ...
                    'chọn bộ giải mã rồi bấm Giải mã'], tenNh, S.snrDb);
                mau = M.chuPhu;
            elseif isequal(S.keysHat, daPhat)
                txt = sprintf('●  Khớp %d/%d phím   ·   %s', numel(daPhat), numel(daPhat), boi);
                mau = M.dung;
            else
                txt = sprintf('●  Lệch: phát %d, đọc %d phím   ·   %s', ...
                    numel(daPhat), numel(S.keysHat), boi);
                mau = M.sai;
            end

            app.LblStatus.Text      = txt;
            app.LblStatus.FontColor = mau;

            capNhatThongTin(app, daPhat, tenPP, tenNh);
        end

        function capNhatThongTin(app, daPhat, tenPP, tenNh)
        %CAPNHATTHONGTIN Dòng thông tin ở góc phải mỗi thẻ bước: bước đó cho ra gì.
        % S.fs hỏng (test cố tình gài một chuỗi) thì thời lượng hiện NaN chứ
        % không ném lỗi: lỗi thật đã nằm ở S.lastError, chỗ này chỉ hiển thị.
            S = app.S;
            fs = NaN;
            if isnumeric(S.fs) && isscalar(S.fs) && S.fs > 0
                fs = S.fs;
            end

            if app.NguonMic
                t1 = 'nguồn ngoài, không có x[n]';
                if isempty(S.y)
                    t2 = 'chưa thu';
                elseif app.TuLuong || strcmp(app.CheDoMic, 'nghe')
                    t2 = sprintf('micro, %.1f s gần nhất', numel(S.y) / fs);
                else
                    t2 = sprintf('bản ghi micro, %.1f s', numel(S.y) / fs);
                end
            else
                t1 = 'chưa có';
                if ~isempty(S.x) && ~isempty(app.TepAm)
                    t1 = sprintf('tệp %s   ·   %.3f s   ·   %d mẫu', ...
                        app.TepAm, numel(S.x) / fs, numel(S.x));
                elseif ~isempty(S.x)
                    t1 = sprintf('%d phím   ·   %.3f s   ·   %d mẫu', ...
                        numel(daPhat), numel(S.x) / fs, numel(S.x));
                end
                t2 = 'chưa cộng nhiễu';
                if ~isempty(S.y)
                    t2 = sprintf('%s   ·   SNR %.0f dB', tenNh, S.snrDb);
                end
            end

            t3 = 'chưa giải mã';
            if S.iSel >= 1 && isfield(S.info, 'reject')
                n = numel(S.info.reject);
                t3 = sprintf('%s   ·   nhận %d/%d khung', tenPP, ...
                    nnz(strcmp(S.info.reject, 'none')), n);
            end

            app.LblInfo(1).Text = t1;
            app.LblInfo(2).Text = t2;
            app.LblInfo(3).Text = t3;
        end

        function [txt, mau] = trangThaiTep(app, tenNh, boi, M)
        %TRANGTHAITEP Dòng trạng thái khi x[n] nạp từ tệp: không có chuỗi đã
        % phát, nên sau khi giải mã chỉ báo số phím đọc được, hoặc lý do loại
        % khung khi đọc được 0 phím - như nguồn micro.
            S = app.S;
            dai = numel(S.x) / S.fs;
            if isempty(S.y)
                txt = sprintf(['○  Đã nạp tệp %s, %.1f s   ·   bước 2   ·   chọn ' ...
                    'loại nhiễu, SNR rồi bấm Cộng nhiễu'], app.TepAm, dai);
                mau = M.chuPhu;
            elseif ~app.DaGiaiMa
                txt = sprintf(['○  Đã cộng nhiễu %s, SNR %.0f dB   ·   bước 3   ·   ' ...
                    'chọn bộ giải mã rồi bấm Giải mã'], tenNh, S.snrDb);
                mau = M.chuPhu;
            elseif ~isempty(S.keysHat)
                txt = sprintf('●  Tệp %s   ·   đọc được %d phím   ·   %s', ...
                    app.TepAm, numel(S.keysHat), boi);
                mau = M.muc;
            else
                txt = sprintf('●  Tệp %s   ·   0 phím   ·   loại: %s', app.TepAm, demLyDo(S));
                mau = M.sai;
            end
        end

        function [txt, mau] = trangThaiMic(app, tenPP, M)
        %TRANGTHAIMIC Dòng trạng thái khi tín hiệu đến từ micro.
        % Không có chuỗi đã phát để so đúng/sai, nên chỉ báo đang làm gì và
        % đọc được bao nhiêu phím. Đọc được 0 phím thì kể lý do loại khung -
        % đó là manh mối đầu tiên khi tập demo: 'twist' nhiều nghĩa là loa
        % lệch biên độ hai nhóm tần số, 'level' nhiều nghĩa là âm quá nhỏ
        % hoặc lẫn tạp âm.
            S = app.S;
            switch app.CheDoMic
                case 'ghi'
                    txt = sprintf('●  Đang ghi âm   ·   %.1f s / tối đa %d s', ...
                        app.DaDoc / S.fs, app.GHI_TOI_DA);
                    mau = M.nhan;
                case 'nghe'
                    txt = sprintf('●  Đang nghe   ·   %d phím   ·   %s', ...
                        numel(app.L.keysHat), tenPP);
                    mau = M.nhan;
                otherwise
                    if isempty(S.y)
                        txt = '○  Chưa có tín hiệu   ·   chọn một cách thu ở bước 1';
                        mau = M.chuMo;
                    elseif app.TuLuong
                        txt = sprintf('●  Đã dừng nghe   ·   %d phím   ·   %s', ...
                            numel(app.L.keysHat), tenPP);
                        mau = M.muc;
                    elseif ~isempty(S.keysHat)
                        txt = sprintf('●  Micro %.1f s   ·   %d phím   ·   %s', ...
                            numel(S.y) / S.fs, numel(S.keysHat), tenPP);
                        mau = M.muc;
                    else
                        txt = sprintf('●  Micro %.1f s   ·   0 phím   ·   loại: %s', ...
                            numel(S.y) / S.fs, demLyDo(S));
                        mau = M.sai;
                    end
            end
        end

        function b = buocTiep(app, dangGo)
        %BUOCTIEP Bước cần làm tiếp theo: 1, 2, 3, hoặc 0 khi đã xong một lượt.
        % Nguồn tổng hợp:
        %   - chưa có x, hoặc chuỗi phím đã sửa sau lần tạo  -> 1
        %   - có x, chưa cộng nhiễu                            -> 2
        %   - có y, chưa giải mã                               -> 3
        % Micro: micro đang nghỉ và chưa có bản ghi -> 1, còn lại 0 (nút micro
        % đang chạy tự đổi màu, xem kieuNutMic).
            S = app.S;
            if app.NguonMic
                b = double(isempty(app.CheDoMic) && isempty(S.y));
                return
            end

            daPhat = [];
            if isstruct(S.meta) && isfield(S.meta, 'keys')
                daPhat = S.meta.keys;
            end

            % x[n] từ tệp thì ô chuỗi phím không mô tả nó, nên chữ đang gõ
            % không kéo bước tiếp về 1.
            if isempty(S.x) || (isempty(app.TepAm) && ~isempty(dangGo) && ~isequal(dangGo, daPhat))
                b = 1;
            elseif isempty(S.y)
                b = 2;
            elseif ~app.DaGiaiMa
                b = 3;
            else
                b = 0;
            end
        end

        function capNhatNut(app, dangGo)
        %CAPNHATNUT Hiện điều khiển của nguồn đang chọn, tô nút và vạch mép thẻ
        % của bước cần làm tiếp theo, khóa nút chưa dùng được.
        % Mục đích: nhìn vào là biết bấm gì. Luật bước tiếp theo: buocTiep.
        % Cộng nhiễu và Giải mã bị khóa khi bước trước chưa có kết quả; Tạo tín
        % hiệu bị khóa khi ô chuỗi phím trống; Nghe bị khóa khi chưa có gì để nghe.
        % dangGo: chữ trong ô chuỗi phím. Lúc đang gõ, EfKeys.Value CHƯA đổi
        % (ValueChanging tới trước), nên EfKeysValueChanging truyền event.Value.
            if nargin < 2
                dangGo = app.EfKeys.Value;
            end
            dangGo = reshape(char(dangGo), 1, []);

            M = ui_theme();
            S = app.S;
            mic  = app.NguonMic;
            ranh = isempty(app.CheDoMic);
            ghi  = strcmp(app.CheDoMic, 'ghi');
            nghe = strcmp(app.CheDoMic, 'nghe');
            bat  = @(v) matlab.lang.OnOffSwitchState(v);

            % Nguồn. Đang dùng micro thì không cho đổi nguồn: đổi là xóa kết
            % quả, mà micro vẫn đang đổ mẫu vào.
            kieuTab(app.BtnSrcGen, ~mic, M);
            kieuTab(app.BtnSrcMic, mic, M);
            app.BtnSrcGen.Enable  = bat(ranh);
            app.BtnSrcMic.Enable  = bat(ranh);
            app.PnlKeypad.Visible = bat(~mic);
            app.PnlMic.Visible    = bat(mic);

            coX  = ~mic && ~isempty(S.x);
            coY  = ~isempty(S.y);
            buoc = buocTiep(app, dangGo);

            % Bước 1
            kieuNut(app.BtnGen, buoc == 1 && ~isempty(dangGo), M);
            app.BtnGen.Enable   = bat(~isempty(dangGo));
            app.BtnPlayX.Enable = bat(ranh && coX);

            % Bước 2 - micro thì cả bước bị khóa: bản ghi đã mang nhiễu thật.
            kieuNut(app.BtnNoise, buoc == 2, M);
            app.BtnNoise.Enable = bat(coX);
            app.DdNoise.Enable  = bat(~mic);
            app.SldSNR.Enable   = bat(~mic);
            app.BtnPlay.Enable  = bat(ranh && coY);

            % Bước 3
            kieuNut(app.BtnDecode, buoc == 3, M);
            app.BtnDecode.Enable = bat(ranh && coY);

            % Micro. Nút đang chạy đổi sang màu nhấn: nhìn là biết micro đang
            % mở; nút micro còn lại bị khóa.
            app.BtnRecord.Enable = bat(ranh || ghi);
            app.BtnListen.Enable = bat(ranh || nghe);
            kieuNutMic(app.BtnListen, nghe, 'Giải mã trực tiếp', 'Dừng nghe', M);
            kieuNutMic(app.BtnRecord, ghi, 'Ghi âm rồi giải mã', 'Dừng ghi và giải mã', M);

            % Thẻ bước: nhãn "BƯỚC k" màu nhấn khi bước đã có kết quả; vạch mép
            % trái màu nhấn ở bước cần làm tiếp, còn lại trùng nền thẻ.
            xong = [coX || (mic && coY), coY, app.DaGiaiMa];
            for i = 1:3
                if xong(i)
                    app.LblSo(i).FontColor = M.nhan;
                else
                    app.LblSo(i).FontColor = M.chuMo;
                end
                if buoc == i
                    app.TheBuoc(i).BackgroundColor = M.nhan;
                else
                    app.TheBuoc(i).BackgroundColor = M.the;
                end
            end
        end

        function doiNguon(app, mic)
        %DOINGUON Chuyển sang nguồn khác và xóa kết quả của nguồn cũ.
        % Xóa vì để lại thì các trục vẫn nói về một tín hiệu không còn liên
        % quan gì tới điều khiển đang hiện. Ô chuỗi phím giữ nguyên: quay lại
        % nguồn tổng hợp là bấm Tạo tín hiệu được ngay.
            app.NguonMic = mic;
            app.TepAm = '';
            xoaKetQua(app);
            app.S.lastError = blanks(0);
            app.S.x    = zeros(1, 0);
            app.S.y    = zeros(1, 0);
            app.S.meta = [];
            app.TuLuong = false;
            veLai(app);
        end

        % ------------------------------------------------------------ micro

        function batDauGhi(app)
        %BATDAUGHI Mở micro và ghi cho tới khi bấm lần nữa hoặc đủ GHI_TOI_DA giây.
        % Đặt CheDoMic TRƯỚC khi mở micro: tick đầu tiên có thể tới ngay sau
        % record() và nó bỏ qua mọi thứ khi CheDoMic còn rỗng.
            docUI(app);
            app.NguonMic = true;
            app.CheDoMic = 'ghi';
            if ~moMic(app)
                app.CheDoMic = '';
                return
            end
            capNhatNut(app);
            capNhatKetQua(app);
        end

        function dungGhi(app)
        %DUNGGHI Dừng ghi, lấy cả bản ghi làm y[n] rồi giải mã.
            y = zeros(1, 0);
            if ~isempty(app.Mic)
                try
                    stop(app.Mic);
                    y = getaudiodata(app.Mic)';     % cột -> hàng
                catch ME
                    ghiNhatKy(app, sprintf('Micro: %s', ME.message));
                end
            end
            tatMic(app);
            app.CheDoMic = '';
            capNhatNut(app);
            napBanGhi(app, y);
        end

        function batDauNghe(app)
        %BATDAUNGHE Dựng bộ giải mã luồng mới, mở micro, xóa màn hình.
            docUI(app);
            xoaKetQua(app);
            app.S.lastError = blanks(0);
            app.S.x    = zeros(1, 0);
            app.S.y    = zeros(1, 0);
            app.S.meta = [];
            app.NguonMic = true;
            app.L = dtmf_listen(struct('fs', app.S.fs, 'method', app.S.method));

            app.CheDoMic = 'nghe';
            if ~moMic(app)
                app.CheDoMic = '';
                veLai(app);
                return
            end
            capNhatNut(app);
            veNghe(app, true);
        end

        function dungNghe(app)
        %DUNGNGHE Đọc nốt phần mẫu thu sau tick cuối, tắt micro, vẽ trạng thái cuối.
            docMic(app);
            tatMic(app);
            app.CheDoMic = '';
            capNhatNut(app);
            veNghe(app, true);
        end

        function doiPhuongPhapMic(app)
        %DOIPHUONGPHAPMIC Đổi bộ giải mã giữa lúc dùng micro.
        % Đang nghe: dựng lại bộ giải mã luồng bằng phương pháp mới, GIỮ các
        % phím đã đọc - khung đang dở của phương pháp cũ không dùng được cho
        % phương pháp mới vì hai bên chia khung khác nhau. Đang ghi: chỉ cần
        % đọc lại UI, phương pháp mới được dùng lúc dừng ghi.
            docUI(app);
            if strcmp(app.CheDoMic, 'nghe')
                app.L = dtmf_listen(struct('fs', app.S.fs, ...
                    'method', app.S.method, 'keysHat', app.L.keysHat));
                veNghe(app, true);
            end
        end

        function ok = moMic(app)
        %MOMIC Mở micro, gắn docMic vào tick của nó rồi bắt đầu ghi.
        % Chạy ẩn nghĩa là đang trong matlab -batch: không đụng thiết bị âm
        % thanh (lý do như phat), để Mic rỗng - test tự đưa mẫu vào.
            ok = true;
            app.Mic   = [];
            app.DaDoc = 0;
            app.MocVe = [];
            if app.UIFigure.Visible == "off"
                return
            end

            [rec, loi] = ui_mic(app.S.fs);
            if isempty(rec)
                ghiNhatKy(app, loi);
                ok = false;
                return
            end

            rec.TimerPeriod = app.CHU_KY_MIC;
            rec.TimerFcn    = @(~, ~) docMic(app);
            try
                record(rec);
            catch ME
                ghiNhatKy(app, sprintf('Không ghi được từ micro: %s', ME.message));
                ok = false;
                return
            end
            app.Mic = rec;
        end

        function tatMic(app)
        %TATMIC Gỡ tick rồi dừng micro. Gỡ tick TRƯỚC để không tick nào chạy sau đó.
            if isempty(app.Mic)
                return
            end
            try
                app.Mic.TimerFcn = [];
                if isrecording(app.Mic)
                    stop(app.Mic);
                end
            catch
                % Micro vừa bị rút giữa chừng thì stop cũng lỗi; việc cần làm
                % lúc này chỉ là bỏ tham chiếu tới nó.
            end
            app.Mic = [];
        end

        function docMic(app)
        %DOCMIC Tick của micro: lấy phần mẫu thu được từ lần đọc trước.
        % getaudiodata trả CẢ bản ghi từ lúc record(), nên phải nhớ DaDoc để
        % chỉ lấy phần mới.
            if ~isvalid(app) || isempty(app.Mic)
                return
            end

            try
                y = getaudiodata(app.Mic);
                moi = y(app.DaDoc+1:end)';
                app.DaDoc = numel(y);

                switch app.CheDoMic
                    case 'nghe'
                        nhanMauMic(app, moi);

                        % Ghi lại từ đầu khi bản ghi quá dài, chọn lúc không
                        % có phím nào đang kêu để khoảng hở vài chục ms giữa
                        % stop và record rơi vào im lặng.
                        if app.DaDoc > app.NGHE_TOI_DA * app.S.fs && app.L.runLen == 0
                            stop(app.Mic);
                            record(app.Mic);
                            app.DaDoc = 0;
                        end
                    case 'ghi'
                        if app.DaDoc >= app.GHI_TOI_DA * app.S.fs
                            dungGhi(app);
                        elseif isempty(app.MocVe) || toc(app.MocVe) >= 0.2
                            capNhatKetQua(app);
                            app.MocVe = tic;
                        end
                end
            catch ME
                ghiNhatKy(app, sprintf('Micro: %s', ME.message));
            end
        end

        function veNghe(app, veTruc)
        %VENGHE Chép kết quả của bộ giải mã luồng sang S rồi hiển thị.
        % veTruc = true vẽ lại mọi trục qua veLai; false chỉ đổi nhãn kết quả.
        % Nhãn "Đọc được" chỉ vừa khoảng 12 ký tự, nên chỉ hiện 12 phím cuối;
        % số phím đầy đủ nằm ở dòng trạng thái.
        % KHÔNG chép L.lastError sang S: ui_refresh ghi S.lastError vào nhật
        % ký mỗi lần vẽ, tức mỗi giây một dòng trùng - nhanMauMic đã ghi rồi.
            app.S.y       = app.L.y;
            app.S.meta    = [];
            app.S.info    = app.L.info;
            app.S.iSel    = app.L.iSel;
            app.S.thr     = app.L.thr;
            app.S.keysHat = app.L.keysHat(max(1, end-11):end);
            app.DaGiaiMa  = true;
            app.TuLuong   = true;

            if veTruc
                veLai(app);
                app.MocVe = tic;
            else
                app.LblDecoded.Text = app.S.keysHat;
                capNhatKetQua(app);
            end
        end

        % ------------------------------------------------------- phát, nhật ký

        function phatPhim(app, ch)
        %PHATPHIM Phát tiếng của ĐÚNG MỘT phím, để bấm tới đâu nghe tới đó.
        % Thoát sớm khi chạy ẩn, trước cả lúc sinh tín hiệu: trong matlab
        % -batch thì 12 lần bấm phím của unit test là 12 lần sinh tone vô ích.
            if app.UIFigure.Visible == "off"
                return
            end

            try
                phat(app, dtmf_generate(ch, 'fs', app.S.fs));
            catch ME
                ghiNhatKy(app, ME.message);
            end
        end

        function phat(app, y)
        %PHAT Phát y nếu giao diện đang hiện, ghi nhật ký nếu không phát được.
            if app.UIFigure.Visible == "off"
                % Chạy ẩn nghĩa là đang trong matlab -batch: đụng vào thiết bị
                % âm thanh ở đó có thể treo cả phiên chạy test.
                return
            end

            if ~ui_play(y, app.S.fs)
                ghiNhatKy(app, 'Không phát được tiếng - máy không có thiết bị âm thanh?');
            end
        end

        function ghiNhatKy(app, dong)
        %GHINHATKY Nối một dòng vào cuối TxtLog.
        % Không đi qua ui_refresh: mỗi lần bấm phím mà vẽ lại cả sáu trục thì
        % bàn phím trễ thấy rõ.
            cu = app.TxtLog.Value;
            if ~iscell(cu)
                cu = cellstr(cu);
            end

            % uitextarea mới dựng có Value = {''} chứ không phải {} - giống
            % chốt trong ui_refresh.
            if isscalar(cu) && isempty(char(cu{1}))
                cu = {};
            end

            app.TxtLog.Value = [cu(:); {dong}];
        end

        function sangPhim(app, ch)
        %SANGPHIM Phím vừa bấm sáng màu nhấn, tần số hàng / cột của nó cũng
        % sáng - thấy ngay phím đó là cặp tần số nào - rồi tắt sau SANG_PHIM
        % giây. Chạy ẩn thì không có đồng hồ: đèn tắt ngay.
            T = dtmf_table();
            [r, c] = find(T.keys == ch, 1);
            if isempty(r)
                return
            end
            g = zeros(1, 12);
            g((r - 1) * 3 + c) = 1;
            ui_pad(app.Ban, g, double((1:4) == r), double((1:3) == c));
            if app.UIFigure.Visible == "off"
                tatPhim(app);
                return
            end
            if isempty(app.NhipPhim) || ~isvalid(app.NhipPhim)
                app.NhipPhim = timer('Name', 'DTMFApp-phim', 'StartDelay', app.SANG_PHIM, ...
                    'TimerFcn', @(~, ~) tatPhim(app));
            end
            stop(app.NhipPhim);
            start(app.NhipPhim);
        end

        function tatPhim(app)
        %TATPHIM Tắt mọi đèn trên bàn phím vẽ.
            if isvalid(app) && ~isempty(app.Ban) && isvalid(app.Ban.pad)
                ui_pad(app.Ban, zeros(1, 12), zeros(1, 4), zeros(1, 3));
            end
        end

        function hienSNR(app, v)
        %HIENSNR Ghi giá trị SNR đang chọn vào nhãn cạnh thanh trượt.
            app.LblSNR.Text = sprintf('%.0f dB', v);
        end

        % ------------------------------------------------------------ dựng hình

        function dungGiaoDien(app, visible)
        %DUNGGIAODIEN Dựng cửa sổ như một trang LaTeX: tiêu đề, đường kẻ đậm,
        % ba mục bước đánh số ngăn bằng vạch mảnh, chân trang trạng thái.
        % Ba mục dùng CÙNG một cách chia cột (theBuoc), nên trục bên trái của
        % cả ba - dạng sóng x[n], dạng sóng y[n], bản đồ khung - thẳng mép nhau
        % tuyệt đối: một thời điểm ở hàng trên nằm đúng trên thời điểm đó ở
        % hàng dưới. Màu và phông: app/ui/ui_theme.m (M.tex cho kiểu LaTeX).
            M = ui_theme();

            % 'Theme', 'light' là BẮT BUỘC, không phải sở thích. Từ R2025a
            % uifigure bám theme của hệ điều hành: máy để Windows ở chế độ tối
            % thì cả giao diện lẫn các trục ra nền ĐEN, và ảnh chụp H3.3 của
            % báo cáo cũng đen theo. Ghim sáng để hình trên giấy, hình trên máy
            % chiếu và hình trên máy người chấm là cùng một hình.
            app.UIFigure = uifigure('Visible', visible, ...
                'Theme', 'light', ...
                'Name', 'DTMF - Phát và giải mã tín hiệu', ...
                'Icon', M.logo, ...
                'Position', viTriCuaSo(), ...
                'Color', M.the, ...
                'CloseRequestFcn', @(src, evt) delete(app));

            g = uigridlayout(app.UIFigure, [5 1]);
            g.RowHeight       = {36, 2, '1x', 1, 30};
            g.ColumnWidth     = {'1x'};
            g.Padding         = [24 10 24 8];
            g.RowSpacing      = 8;
            g.BackgroundColor = M.the;

            dungTieuDe(app, g, M);
            ke(g, 2, 1, M.tex.ke);

            % Bước 1 cao hơn hai bước kia vì phải chứa đủ bàn phím 4×3.
            gb = uigridlayout(g, [5 1]);
            gb.RowHeight       = {'1.5x', 1, '1x', 1, '1x'};
            gb.ColumnWidth     = {'1x'};
            gb.Padding         = [0 0 0 0];
            gb.RowSpacing      = 6;
            gb.BackgroundColor = M.the;
            gb.Layout.Row      = 3;

            [p1, c1, s1, i1] = theBuoc(gb, 1, 1, 'Tín hiệu gốc', ...
                ['<i>x</i>[<i>n</i>] = <i>A</i> sin(2π<i>f</i><sub>R</sub><i>n</i>/<i>f</i><sub>s</sub>)' ...
                 ' + <i>A</i> sin(2π<i>f</i><sub>C</sub><i>n</i>/<i>f</i><sub>s</sub>)'], M);
            ke(gb, 2, 1, M.vien);
            [p2, c2, s2, i2] = theBuoc(gb, 3, 2, 'Kênh nhiễu', ...
                '<i>y</i>[<i>n</i>] = <i>x</i>[<i>n</i>] + <i>v</i>[<i>n</i>]', M);
            ke(gb, 4, 1, M.vien);
            [p3, c3, s3, i3] = theBuoc(gb, 5, 3, 'Giải mã', ...
                'khung &rarr; <i>E</i><sub><i>j</i></sub> &rarr; chấp nhận khung &rarr; phím', M);
            app.TheBuoc = [p1 p2 p3];
            app.LblSo   = [s1 s2 s3];
            app.LblInfo = [i1 i2 i3];

            dungBuocNguon(app, c1, M);
            dungBuocKenh(app, c2, M);
            dungBuocGiaiMa(app, c3, M);
            ke(g, 4, 1, M.vien);
            dungThanhTrangThai(app, g, M);

            % Phông chữ đặt MỘT lần cho mọi thứ có chữ, trừ những ô cố ý dùng
            % phông đơn cách (chuỗi phím, kết quả, nhật ký) - cột ký tự thẳng
            % hàng là thứ giúp so "đã phát" với "đọc được" - và bàn phím, nơi
            % ui_pad tự chọn phông không chân.
            h = findall(app.UIFigure, '-property', 'FontName');
            for i = 1:numel(h)
                if ~strcmp(h(i).FontName, M.tex.mono) && ...
                        ~isequal(ancestor(h(i), 'axes'), app.AxKeypad)
                    h(i).FontName = M.tex.font;
                end
            end
        end

        function dungTieuDe(app, cha, M)
        %DUNGTIEUDE Dòng tiêu đề: tên và thông số nghiêng bên trái, chọn nguồn
        % bên phải. Chọn nguồn đặt ở đây chứ không trong một mục bước vì nó đổi
        % cách cả ba bước làm việc.
            g = uigridlayout(cha, [1 4]);
            g.ColumnWidth     = {'fit', 'fit', '1x', 216};
            g.Padding         = [0 2 0 2];
            g.ColumnSpacing   = 12;
            g.BackgroundColor = M.the;
            g.Layout.Row      = 1;

            uilabel(g, 'Text', 'Phát và giải mã tín hiệu DTMF', ...
                'FontSize', 23, 'FontColor', M.muc);
            uilabel(g, 'Text', 'ITU-T Q.23  ·  fs = 8000 Hz', ...
                'FontSize', 14, 'FontAngle', 'italic', 'FontColor', M.chuPhu);

            gs = uigridlayout(g, [1 2]);
            gs.ColumnWidth     = {'1x', '1x'};
            gs.Padding         = [0 0 0 0];
            gs.ColumnSpacing   = 6;
            gs.BackgroundColor = M.the;
            gs.Layout.Column   = 4;
            app.BtnSrcGen = uibutton(gs, 'Text', 'Tổng hợp', 'FontSize', 14, ...
                'Tooltip', 'Nguồn tổng hợp: gõ chuỗi phím, tạo x[n], cộng nhiễu thành y[n] rồi giải mã', ...
                'ButtonPushedFcn', @(src, evt) app.BtnSrcPushed(evt));
            app.BtnSrcMic = uibutton(gs, 'Text', 'Micro', 'FontSize', 14, ...
                'Tooltip', 'Nguồn micro: giải mã âm DTMF thu được, vd. bấm số trên điện thoại', ...
                'ButtonPushedFcn', @(src, evt) app.BtnSrcPushed(evt));
        end

        function dungBuocNguon(app, c, M)
        %DUNGBUOCNGUON Mục 1: điều khiển của hai nguồn chồng lên nhau ở cột
        % trái - capNhatNut ẩn cái không dùng - và hai trục của x[n].
        % Ô chuỗi phím nằm NGAY TRÊN bàn phím: bấm phím nào thấy ký tự hiện
        % ra ở đó. Bàn phím vẽ bằng ui_pad: phím phẳng bo góc, tần số hàng và
        % cột của mỗi phím nằm ở đầu hàng và đầu cột.
            app.PnlKeypad = uipanel(c, 'BorderType', 'none', 'BackgroundColor', M.the);
            app.PnlKeypad.Layout.Row = 1;  app.PnlKeypad.Layout.Column = 1;

            kg = uigridlayout(app.PnlKeypad, [4 2]);
            kg.RowHeight       = {28, '1x', 28, 28};
            kg.ColumnWidth     = {'1x', 64};
            kg.Padding         = [0 0 0 0];
            kg.RowSpacing      = 6;
            kg.ColumnSpacing   = 6;
            kg.BackgroundColor = M.the;

            app.EfKeys = uieditfield(kg, 'text', ...
                'FontName', M.tex.mono, 'FontSize', 15, 'FontColor', M.muc, ...
                'ValueChangingFcn', @(src, evt) app.EfKeysValueChanging(evt));
            app.EfKeys.Layout.Row = 1;  app.EfKeys.Layout.Column = 1;

            app.BtnClear = uibutton(kg, 'Text', 'Xóa', ...
                'FontSize', 13, 'FontColor', M.chuPhu, 'BackgroundColor', M.the, ...
                'Tooltip', 'Xóa chuỗi phím (tín hiệu đang có giữ nguyên)', ...
                'ButtonPushedFcn', @(src, evt) app.BtnClearPushed(evt));
            app.BtnClear.Layout.Row = 1;  app.BtnClear.Layout.Column = 2;

            % Bảng phím: trục trong một panel trơn, chiếm trọn ô; ui_pad giữ tỉ
            % lệ 1:1 nên bảng tự canh giữa.
            v = uipanel(kg, 'BorderType', 'none', 'BackgroundColor', M.the, ...
                'AutoResizeChildren', 'off');
            v.Layout.Row = 2;  v.Layout.Column = [1 2];
            app.AxKeypad = uiaxes(v, 'Units', 'pixels', 'Color', M.the);
            app.AxKeypad.Position = [0 0 v.InnerPosition(3:4)];
            app.Ban = ui_pad(app.AxKeypad, false);
            v.SizeChangedFcn = @(src, ~) coBanPhim(app.Ban, src);
            app.Ban.pad.ButtonDownFcn = @(src, evt) app.AxKeypadClicked(evt);

            % 12 nút thật, ẩn trong một panel ẩn cùng ô - xem khai báo Btn1.
            an = uipanel(kg, 'Visible', 'off', 'BorderType', 'none');
            an.Layout.Row = 2;  an.Layout.Column = [1 2];
            T = dtmf_table();
            ten = {'Btn1', 'Btn2', 'Btn3', 'Btn4', 'Btn5', 'Btn6', ...
                   'Btn7', 'Btn8', 'Btn9', 'BtnStar', 'Btn0', 'BtnHash'};
            ky  = {'1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'};
            for i = 1:numel(ten)
                app.(ten{i}) = uibutton(an, 'Text', ky{i}, ...
                    'Tooltip', sprintf('%d Hz + %d Hz', ...
                        T.rowHz(ceil(i / 3)), T.colHz(mod(i - 1, 3) + 1)), ...
                    'ButtonPushedFcn', @(src, evt) app.Btn1Pushed(evt));
            end

            app.BtnGen = uibutton(kg, 'Text', 'Tạo tín hiệu', 'FontSize', 14, ...
                'Tooltip', 'Sinh tín hiệu DTMF sạch từ chuỗi phím, chưa có nhiễu', ...
                'ButtonPushedFcn', @(src, evt) app.BtnGenPushed(evt));
            app.BtnGen.Layout.Row = 3;  app.BtnGen.Layout.Column = 1;
            app.BtnPlayX = uibutton(kg, 'Text', 'Nghe', 'FontSize', 13, ...
                'FontColor', M.muc, 'BackgroundColor', M.the, ...
                'Tooltip', 'Phát ra loa tín hiệu gốc, chưa có nhiễu', ...
                'ButtonPushedFcn', @(src, evt) app.BtnPlayXPushed(evt));
            app.BtnPlayX.Layout.Row = 3;  app.BtnPlayX.Layout.Column = 2;

            % Lối thứ hai vào bước 1: tệp âm thanh thay cho chuỗi phím.
            app.BtnOpen = uibutton(kg, 'Text', 'Mở tệp âm thanh…', 'FontSize', 13, ...
                'FontColor', M.muc, 'BackgroundColor', M.the, ...
                'Tooltip', sprintf(['Nạp một tệp wav, flac, mp3... làm x[n]: lấy trung bình ' ...
                    'các kênh, đổi về 8 kHz, tối đa %d s'], app.TEP_TOI_DA), ...
                'ButtonPushedFcn', @(src, evt) app.BtnOpenPushed(evt));
            app.BtnOpen.Layout.Row = 4;  app.BtnOpen.Layout.Column = [1 2];

            dungTheMic(app, c, M);

            app.AxWaveX = trucTrongO(c, 2, app.leThoiGian(), M);
            app.AxPsdX  = trucTrongO(c, 3, app.lePho(), M);
        end

        function dungTheMic(app, c, M)
        %DUNGTHEMIC Điều khiển bước 1 của nguồn micro: một dòng hướng dẫn, hai nút.
        % Khi nào dùng nút nào nằm trong tooltip, không chiếm chỗ trên màn hình.
        % Nghe trực tiếp đặt TRƯỚC vì đó là cách trình diễn chính; ghi âm là
        % cách dự phòng khi cần xem đủ các đồ thị của cả bản ghi.
            app.PnlMic = uipanel(c, 'BorderType', 'none', 'BackgroundColor', M.the);
            app.PnlMic.Layout.Row = 1;  app.PnlMic.Layout.Column = 1;

            gm = uigridlayout(app.PnlMic, [4 1]);
            gm.RowHeight       = {40, 30, 30, '1x'};
            gm.ColumnWidth     = {'1x'};
            gm.Padding         = [0 0 0 0];
            gm.RowSpacing      = 8;
            gm.BackgroundColor = M.the;

            uilabel(gm, 'WordWrap', 'on', 'FontSize', 13, 'FontAngle', 'italic', ...
                'FontColor', M.chuPhu, ...
                'Text', 'Đặt điện thoại cách micro 5–10 cm và bật âm bàn phím.');

            app.BtnListen = uibutton(gm, 'FontSize', 14, ...
                'Tooltip', ['Nghe micro liên tục, phím hiện ra ngay khi nhận ra; ' ...
                    'bấm lần nữa để dừng. Dùng để trình diễn trực tiếp.'], ...
                'ButtonPushedFcn', @(src, evt) app.BtnListenPushed(evt));

            app.BtnRecord = uibutton(gm, 'FontSize', 14, ...
                'Tooltip', sprintf(['Ghi âm tối đa %d s; bấm lần nữa để dừng và giải ' ...
                    'mã cả bản ghi. Đọc được 0 phím thì thanh trạng thái ghi lý do: ' ...
                    'twist là hai âm lệch biên độ, level là âm quá nhỏ.'], app.GHI_TOI_DA), ...
                'ButtonPushedFcn', @(src, evt) app.BtnRecordPushed(evt));
        end

        function dungBuocKenh(app, c, M)
        %DUNGBUOCKENH Mục 2: loại nhiễu, SNR, nút Cộng nhiễu, và hai trục của y[n].
        % Nút Nghe đứng cạnh nút Cộng nhiễu: nghe lại đúng cái bộ giải mã sắp nghe.
            % Nút ngay dưới tham số, phần trống dồn xuống đáy - cùng kiểu với
            % mục 3: tham số trên, nút hành động ngay dưới.
            gk = uigridlayout(c, [4 2]);
            gk.RowHeight       = {28, 40, 28, '1x'};
            gk.ColumnWidth     = {78, '1x'};
            gk.Padding         = [0 0 0 0];
            gk.RowSpacing      = 6;
            gk.ColumnSpacing   = 6;
            gk.BackgroundColor = M.the;
            gk.Layout.Row      = 1;
            gk.Layout.Column   = 1;

            nhanTinh(gk, 1, 'Loại nhiễu', M);
            app.DdNoise = uidropdown(gk, ...
                'Items',     {'Gauss trắng (AWGN)', 'Điện lưới 50 Hz'}, ...
                'ItemsData', {'awgn', 'hum50'}, ...
                'Value',     app.S.noise, 'FontSize', 14, ...
                'FontColor', M.muc, 'BackgroundColor', M.the, ...
                'Tooltip', 'Dạng của v[n]; công suất do SNR quyết định', ...
                'ValueChangedFcn', @(src, evt) app.DdNoiseValueChanged(evt));
            app.DdNoise.Layout.Row = 1;  app.DdNoise.Layout.Column = 2;

            % Thanh trượt nằm ở mép trên hàng, vạch chia bên dưới: nhãn hai bên
            % cũng canh trên để ba thứ thẳng một đường.
            l = nhanTinh(gk, 2, 'SNR', M);
            l.VerticalAlignment = 'top';
            gs = uigridlayout(gk, [1 2]);
            gs.ColumnWidth     = {'1x', 48};
            gs.Padding         = [0 0 0 0];
            gs.ColumnSpacing   = 6;
            gs.BackgroundColor = M.the;
            gs.Layout.Row      = 2;
            gs.Layout.Column   = 2;
            app.SldSNR = uislider(gs, ...
                'Limits',          [-5 30], ...
                'Value',           app.S.snrDb, ...
                'MajorTicks',      -5:5:30, ...
                'MinorTicks',      [], ...
                'FontSize',        11, ...
                'FontColor',       M.chuPhu, ...
                'Tooltip', ['SNR = 10 log10(Px / Pv). Đã cộng nhiễu mà đổi SNR thì nhiễu ' ...
                    'được cộng lại vào cùng x[n], các bước sau tự chạy lại.'], ...
                'ValueChangingFcn', @(src, evt) app.SldSNRValueChanging(evt), ...
                'ValueChangedFcn',  @(src, evt) app.SldSNRValueChanged(evt));
            app.LblSNR = uilabel(gs, 'Text', blanks(0), ...
                'FontSize', 14, 'FontWeight', 'bold', 'FontColor', M.nhan, ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
            hienSNR(app, app.S.snrDb);

            gn = uigridlayout(gk, [1 2]);
            gn.ColumnWidth     = {'1x', 64};
            gn.Padding         = [0 0 0 0];
            gn.ColumnSpacing   = 6;
            gn.BackgroundColor = M.the;
            gn.Layout.Row      = 3;
            gn.Layout.Column   = [1 2];
            app.BtnNoise = uibutton(gn, 'Text', 'Cộng nhiễu', 'FontSize', 14, ...
                'Tooltip', 'y[n] = x[n] + v[n], v[n] theo loại nhiễu và SNR đang chọn', ...
                'ButtonPushedFcn', @(src, evt) app.BtnNoisePushed(evt));
            app.BtnPlay = uibutton(gn, 'Text', 'Nghe', 'FontSize', 13, ...
                'FontColor', M.muc, 'BackgroundColor', M.the, ...
                'Tooltip', 'Phát ra loa đúng tín hiệu bộ giải mã nghe (đã cộng nhiễu, hoặc bản ghi micro)', ...
                'ButtonPushedFcn', @(src, evt) app.BtnPlayPushed(evt));

            app.AxWave = trucTrongO(c, 2, app.leThoiGian(), M);
            app.AxPsd  = trucTrongO(c, 3, app.lePho(), M);
        end

        function dungBuocGiaiMa(app, c, M)
        %DUNGBUOCGIAIMA Mục 3: bộ giải mã, nút Giải mã, kết quả, và hai trục của bộ giải mã.
        % Chuỗi đã phát nằm ngay trên chuỗi đọc được, cùng phông đơn cách để
        % mắt so được từng cột ký tự. Màu chữ LblDecoded (đúng xanh / sai đỏ)
        % do ui_refresh đặt; LblSent do capNhatKetQua đặt.
            gd = uigridlayout(c, [5 2]);
            gd.RowHeight       = {28, 28, '1x', 22, 32};
            gd.ColumnWidth     = {78, '1x'};
            gd.Padding         = [0 0 0 0];
            gd.RowSpacing      = 6;
            gd.ColumnSpacing   = 6;
            gd.BackgroundColor = M.the;
            gd.Layout.Row      = 1;
            gd.Layout.Column   = 1;

            nhanTinh(gd, 1, 'Bộ giải mã', M);
            app.DdMethod = uidropdown(gd, ...
                'Items',     {'FFT', 'Goertzel', 'Ngân hàng bộ lọc'}, ...
                'ItemsData', {'fft', 'goertzel', 'filterbank'}, ...
                'Value',     app.S.method, 'FontSize', 14, ...
                'FontColor', M.muc, 'BackgroundColor', M.the, ...
                'Tooltip', 'Đã giải mã rồi mà đổi bộ giải mã thì giải mã lại ngay', ...
                'ValueChangedFcn', @(src, evt) app.DdMethodValueChanged(evt));
            app.DdMethod.Layout.Row = 1;  app.DdMethod.Layout.Column = 2;

            app.BtnDecode = uibutton(gd, 'Text', 'Giải mã', 'FontSize', 14, ...
                'Tooltip', 'Tìm phím trong y[n] bằng bộ giải mã đang chọn', ...
                'ButtonPushedFcn', @(src, evt) app.BtnDecodePushed(evt));
            app.BtnDecode.Layout.Row = 2;  app.BtnDecode.Layout.Column = [1 2];

            nhanTinh(gd, 4, 'Đã phát', M);
            app.LblSent = uilabel(gd, 'Text', blanks(0), ...
                'FontName', M.tex.mono, 'FontSize', 14, 'FontColor', M.chuPhu);
            app.LblSent.Layout.Row = 4;  app.LblSent.Layout.Column = 2;

            nhanTinh(gd, 5, 'Đọc được', M);
            app.LblDecoded = uilabel(gd, 'Text', blanks(0), ...
                'FontName', M.tex.mono, 'FontSize', 22, 'FontWeight', 'bold', ...
                'FontColor', M.muc);
            app.LblDecoded.Layout.Row = 5;  app.LblDecoded.Layout.Column = 2;

            app.AxMap  = trucTrongO(c, 2, app.leThoiGian(), M);
            app.AxBars = trucTrongO(c, 3, app.leThanh(), M);
        end

        function dungThanhTrangThai(app, cha, M)
        %DUNGTHANHTRANGTHAI Chân trang: một dòng trạng thái nghiêng của cả quy
        % trình bên trái, nhật ký lỗi bên phải. Nhật ký chỉ ghi lỗi nên để nhỏ.
            gs = uigridlayout(cha, [1 2]);
            gs.ColumnWidth     = {'1x', 420};
            gs.RowHeight       = {'1x'};
            gs.Padding         = [0 0 0 0];
            gs.ColumnSpacing   = 16;
            gs.BackgroundColor = M.the;
            gs.Layout.Row      = 5;

            app.LblStatus = uilabel(gs, 'Text', blanks(0), ...
                'FontSize', 13, 'FontAngle', 'italic', 'FontColor', M.chuMo);

            app.TxtLog = uitextarea(gs, 'Editable', 'off', ...
                'FontName', M.tex.mono, 'FontSize', 11, 'FontColor', M.sai, ...
                'BackgroundColor', M.the, ...
                'Placeholder', 'Nhật ký lỗi: chưa có lỗi nào');
        end

    end

    methods (Static, Access = private)
        % Lề khung vẽ [trái dưới phải trên], pixel từ mép vùng vẽ của ô: chừa
        % chỗ cho nhãn trục và tiêu đề. Ba trục thời gian dùng CHUNG một lề để
        % thẳng mép nhau; trục thanh cao hơn ở trên vì có thêm phụ đề.
        function le = leThoiGian()
            le = [62 40 10 26];
        end
        function le = lePho()
            le = [56 40 10 26];
        end
        function le = leThanh()
            le = [56 40 10 44];
        end
    end

end

% ================================================================ hàm cục bộ

function pos = viTriCuaSo()
%VITRICUASO Cửa sổ 1400×860, co lại cho vừa màn hình nhỏ, đặt giữa màn hình.
% Màn hình 1920×1080 để Windows phóng 125% chỉ còn 1536×864 điểm ảnh logic,
% trừ thanh tác vụ - cố định 860 là tràn đáy.
scr = get(groot, 'ScreenSize');
w = min(1400, max(1100, scr(3) - 80));
h = min(860,  max(720,  scr(4) - 110));
pos = [max(1, round((scr(3) - w) / 2)), max(40, round((scr(4) - h) / 2)), w, h];
end

function coBanPhim(ban, p)
%COBANPHIM Trục bàn phím chiếm trọn panel P, rồi ui_pad đặt lại cỡ chữ.
ban.ax.Position = [0 0 p.InnerPosition(3:4)];
ui_pad(ban, 'co');
end

function ke(g, hang, cot, mau)
%KE Một đường kẻ lấp đầy ô (hang, cot) - ô cao 1-2 px là kẻ ngang.
v = uipanel(g, 'BorderType', 'none', 'BackgroundColor', mau);
v.Layout.Row = hang;
v.Layout.Column = cot;
end

function [vach, c, lblSo, lblInfo] = theBuoc(cha, hang, so, ten, congThuc, M)
%THEBUOC Mục của bước thứ SO ở hàng HANG: không thẻ, không viền, như một
% \section. Mép trái là một vạch 2 px kiểu changebar - capNhatNut tô màu nhấn
% cho bước cần làm tiếp, còn lại trùng màu nền nên không thấy. Dòng đầu: số
% mục, tên mục, công thức, dòng thông tin nghiêng canh phải. Thân: ba cột -
% điều khiển | trục miền thời gian | trục miền tần số. Cả ba mục dùng ĐÚNG
% cách chia cột này, nên trục cột 2 của ba mục thẳng mép nhau theo chiều dọc.
p = uipanel(cha, 'BackgroundColor', M.the, 'BorderType', 'none');
p.Layout.Row = hang;

gv = uigridlayout(p, [1 2]);
gv.ColumnWidth     = {2, '1x'};
gv.RowHeight       = {'1x'};
gv.Padding         = [0 0 0 0];
gv.ColumnSpacing   = 0;
gv.BackgroundColor = M.the;

vach = uilabel(gv, 'Text', '', 'BackgroundColor', M.the);

gp = uigridlayout(gv, [2 1]);
gp.RowHeight       = {24, '1x'};
gp.ColumnWidth     = {'1x'};
gp.Padding         = [12 6 0 4];
gp.RowSpacing      = 6;
gp.BackgroundColor = M.the;

gh = uigridlayout(gp, [1 4]);
gh.ColumnWidth     = {'fit', 'fit', '1x', 'fit'};
gh.RowHeight       = {'1x'};
gh.Padding         = [0 0 0 0];
gh.ColumnSpacing   = 14;
gh.BackgroundColor = M.the;

lblSo = uilabel(gh, 'Text', sprintf('%d', so), 'FontSize', 17, ...
    'FontWeight', 'bold', 'FontColor', M.chuMo);
uilabel(gh, 'Text', ten, 'FontSize', 17, 'FontWeight', 'bold', 'FontColor', M.muc);
uilabel(gh, 'Text', congThuc, 'Interpreter', 'html', 'FontSize', 15, 'FontColor', M.chuPhu);
lblInfo = uilabel(gh, 'Text', '', 'FontSize', 13, 'FontAngle', 'italic', ...
    'FontColor', M.chuPhu, 'HorizontalAlignment', 'right');

c = uigridlayout(gp, [1 3]);
c.ColumnWidth     = {270, '1.4x', '1x'};
c.RowHeight       = {'1x'};
c.Padding         = [0 0 0 0];
c.ColumnSpacing   = 24;
c.BackgroundColor = M.the;
end

function ax = trucTrongO(c, cot, le, M)
%TRUCTRONGO Một uiaxes đặt tay trong ô cột COT của thân mục bước.
% Trục KHÔNG nằm thẳng trong uigridlayout mà trong một panel trơn, đặt tay
% InnerPosition với lề LE: trong grid, MATLAB tự co khung vẽ theo bề rộng
% nhãn tick - '0.5' hẹp hơn '3000' - nên hai trục chồng nhau lệch mép; đặt
% PositionConstraint = 'innerposition' trong grid cũng không cứu được (đo
% 25/09/2026: khung vẽ bị ép còn một phần ba chiều cao thẻ).
v = uipanel(c, 'BorderType', 'none', ...
    'BackgroundColor', M.the, 'AutoResizeChildren', 'off');
v.Layout.Row = 1;  v.Layout.Column = cot;

% Tắt tự co giãn thì SizeChangedFcn mới được gọi.
ax = uiaxes(v, 'Units', 'pixels', 'PositionConstraint', 'innerposition');

% Ẩn thanh công cụ "•••" ở góc trục: sáu trục là sáu cụm nút lơ lửng. Cuộn
% chuột vẫn phóng to được; lần vẽ sau tự đặt lại giới hạn trục.
ax.Toolbar.Visible = 'off';

v.SizeChangedFcn = @(src, ~) canTruc(ax, src, le);
canTruc(ax, v, le);
end

function canTruc(ax, p, le)
%CANTRUC Đặt khung vẽ của AX cách mép trong panel P đúng LE = [trái dưới phải trên].
% Gọi lại mỗi lần panel đổi cỡ. max(..., 1): cửa sổ kéo quá nhỏ cho bề rộng
% âm, mà InnerPosition âm là lỗi.
k = p.InnerPosition;
ax.InnerPosition = [le(1), le(2), ...
                    max(k(3) - le(1) - le(3), 1), max(k(4) - le(2) - le(4), 1)];
end

function tieuDe(ax, s)
%TIEUDE Đổi chữ tiêu đề trục mà giữ màu, cỡ, canh lề ui_refresh đã đặt.
ax.Title.String = s;
end

function s = tenMuc(dd, giaTri)
%TENMUC Tên hiển thị của một giá trị dropdown; giá trị lạ thì hiện nguyên văn.
% S.method lạ (test cố tình gài) phải hiện ra được, không ném lỗi.
s = char(string(giaTri));
k = find(strcmp(dd.ItemsData, giaTri), 1);
if ~isempty(k)
    s = dd.Items{k};
end
end

function s = tenNhieu(loai)
%TENNHIEU Tên ngắn của loại nhiễu cho dòng trạng thái.
switch loai
    case 'awgn'
        s = 'AWGN';
    case 'hum50'
        s = 'điện lưới 50 Hz';
    otherwise
        s = char(string(loai));
end
end

function l = nhanTinh(cha, hang, nhan, M)
%NHANTINH Nhãn chú thích tĩnh ở cột 1 - không cần đặt tên, docs/ui_naming.md §1.
l = uilabel(cha, 'Text', nhan, 'FontSize', 14, 'FontColor', M.chuPhu);
l.Layout.Row    = hang;
l.Layout.Column = 1;
end

function kieuNut(nut, buocTiep, M)
%KIEUNUT Nút của bước cần bấm tiếp theo: nền gần đen, chữ trắng đậm - đơn
% sắc như trang LaTeX. Nút khác: nền trắng, chữ thường. FontWeight là dấu hiệu
% test đọc được, không phải chỉ để trang trí.
if buocTiep
    set(nut, 'FontWeight', 'bold', 'FontColor', [1 1 1], 'BackgroundColor', M.muc);
else
    set(nut, 'FontWeight', 'normal', 'FontColor', M.muc, 'BackgroundColor', M.the);
end
end

function kieuNutMic(nut, dangChay, chuNghi, chuChay, M)
%KIEUNUTMIC Nút micro lúc nghỉ: nền trắng; lúc chạy: nền gần đen, chữ "Dừng".
if dangChay
    set(nut, 'Text', chuChay);
else
    set(nut, 'Text', chuNghi);
end
kieuNut(nut, dangChay, M);
end

function kieuTab(nut, dangChon, M)
%KIEUTAB Nút nguồn đang chọn: chữ đậm trên nền xám rất nhạt - khác hẳn nút
% hành động (nền đặc) để không ai tưởng bấm vào là "chạy" thứ gì.
if dangChon
    set(nut, 'FontWeight', 'bold', 'FontColor', M.muc, 'BackgroundColor', M.phimPhu);
else
    set(nut, 'FontWeight', 'normal', 'FontColor', M.chuPhu, 'BackgroundColor', M.the);
end
end

function s = demLyDo(S)
%DEMLYDO Đếm lý do loại khung trong S.info, vd. 'level 150, twist 23'.
% Chỉ đếm nhãn dtmf_decide đã gắn - không phép tính DSP nào, luật §2.
if ~isfield(S.info, 'reject') || isempty(S.info.reject)
    s = 'không có khung nào';
    return
end
ten = {'level', 'twist', 'harmonic'};
dem = cellfun(@(t) nnz(strcmp(S.info.reject, t)), ten);
co  = dem > 0;
if ~any(co)
    % Mọi khung đều được nhận mà vẫn 0 phím: không dải nào đủ minRun khung.
    s = 'không dải nào đủ 2 khung';
    return
end
% sprintf từng cặp chứ không compose: compose với một mảng chuỗi và một mảng
% số cùng lúc ném lỗi "Conversion to int64 from string" khi có >= 2 lý do.
phan = cellfun(@(t, n) sprintf('%s %d', t, n), ten(co), num2cell(dem(co)), ...
    'UniformOutput', false);
s = strjoin(phan, ', ');
end
