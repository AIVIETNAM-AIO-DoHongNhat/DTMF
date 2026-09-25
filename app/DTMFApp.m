classdef DTMFApp < handle
%DTMFAPP Giao diện phát và giải mã DTMF: bàn phím, thanh SNR, ba bộ giải mã
% Bấm số như bấm điện thoại, nghe tiếng, rồi xem máy đọc lại đúng những phím đó
%   APP = DTMFAPP() mở giao diện. APP = DTMFAPP('off') dựng giao diện ẩn để
%   chạy tự động trong matlab -batch; lúc ẩn thì không phát ra tiếng.
%
%   Các bước hoạt động:
%       1. Constructor dựng struct trạng thái S mặc định, dựng toàn bộ
%          component theo docs/ui_naming.md, rồi gọi ui_refresh một lần để
%          ba trục có nội dung ngay khi cửa sổ hiện lên.
%       2. Mỗi callback làm đúng ba việc: đọc UI vào S, gọi lớp tính toán
%          (dtmf_run, hoặc sinhTinHieu cho nhánh phát), rồi ui_refresh(app).
%       3. Không một phép tính DSP nào nằm trong callback - luật CONTRACTS §2
%          và §6(h). Callback chỉ điều phối.
%
%   Vì sao classdef chứ không phải .mlapp: .mlapp là file ZIP nhị phân, không
%   diff, không merge và không chạy được trong matlab -batch. ui_refresh chỉ
%   đụng sáu thành phần AxWave, AxSpec, AxBars, LblDecoded, TxtLog và S, nên
%   một classdef có đúng các property đó thỏa mãn hợp đồng y hệt class do App
%   Designer sinh ra - xem CONTRACTS §8.
%
%   Chữ ký callback giữ nguyên dạng App Designer tự sinh, tức (app, event) với
%   event.Source là component vừa bấm. Nhờ vậy nếu sau này phải nộp đúng file
%   .mlapp thì chỉ cần kéo thả component rồi dán nguyên thân callback sang,
%   không phải sửa một dòng nào.
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
%       app.BtnGenPushed([]);
%       app.BtnDecodePushed([]);
%       app.LblDecoded.Text     % '0912345'

    properties (Access = public)
        UIFigure    matlab.ui.Figure
        PnlKeypad   matlab.ui.container.Panel

        % Bàn phím. Tên đóng băng theo docs/ui_naming.md §2: '*' và '#' không
        % hợp lệ trong tên biến MATLAB nên viết chữ, còn Text của nút vẫn là
        % ký tự thật.
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

        AxWave      matlab.ui.control.UIAxes
        AxSpec      matlab.ui.control.UIAxes
        AxBars      matlab.ui.control.UIAxes

        EfKeys      matlab.ui.control.EditField
        BtnClear    matlab.ui.control.Button
        DdMethod    matlab.ui.control.DropDown
        SldSNR      matlab.ui.control.Slider
        LblSNR      matlab.ui.control.Label
        BtnGen      matlab.ui.control.Button
        BtnDecode   matlab.ui.control.Button
        BtnPlay     matlab.ui.control.Button

        LblSent     matlab.ui.control.Label
        LblDecoded  matlab.ui.control.Label
        LblStatus   matlab.ui.control.Label
        TxtLog      matlab.ui.control.TextArea

        % Một property trạng thái DUY NHẤT, không rải biến rời rạc. Danh sách
        % trường: docs/ui_naming.md §5.
        S           struct
    end

    properties (Access = private)
        % Tín hiệu hiện tại đã qua bộ giải mã chưa. Không suy được từ S: sau
        % "Phát tín hiệu" và sau một lần giải mã không ra phím nào, S.keysHat
        % cùng rỗng và S.iSel cùng bằng 0 - nhưng dòng trạng thái phải nói hai
        % điều khác nhau. Không nằm trong S vì dtmf_run không cần biết.
        DaGiaiMa    logical = false
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
                           'snrDb',     20, ...
                           'method',    'goertzel', ...
                           'keysHat',   blanks(0), ...
                           'info',      struct('E', zeros(8, 0)), ...
                           'thr',       0, ...
                           'iSel',      0, ...
                           'lastError', blanks(0));

            dungGiaoDien(app, visible);

            % Vẽ ngay để ba trục có tiêu đề "chưa có tín hiệu" thay vì ba ô
            % trắng không rõ là đang hỏng hay đang chờ.
            veLai(app);
        end

        function delete(app)
        %DELETE Đóng cửa sổ khi đối tượng bị hủy.
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end

        % ------------------------------------------------------------ callback
        %
        % Cả tám callback dưới đây để PUBLIC, khác App Designer (mặc định
        % private), vì unit test gọi thẳng chúng: không có API công khai nào
        % để "bấm" một uibutton bằng code.

        function Btn1Pushed(app, event)
        %BTN1PUSHED Callback dùng chung cho cả 12 nút bàn phím.
            app.EfKeys.Value = [app.EfKeys.Value, event.Source.Text];
            phatPhim(app, event.Source.Text);
        end

        function BtnGenPushed(app, ~)
        %BTNGENPUSHED Sinh tín hiệu từ chuỗi phím đang gõ, chưa giải mã.
            docUI(app);
            sinhTinHieu(app);
            veLai(app);
        end

        function BtnDecodePushed(app, ~)
        %BTNDECODEPUSHED Giải mã tín hiệu hiện có bằng phương pháp đang chọn.
            docUI(app);
            giaiMa(app);
            veLai(app);
        end

        function BtnPlayPushed(app, ~)
        %BTNPLAYPUSHED Phát tín hiệu ĐÃ CỘNG NHIỄU - đúng cái bộ giải mã nghe.
            phat(app, app.S.y);
        end

        function DdMethodValueChanged(app, ~)
        %DDMETHODVALUECHANGED Đổi bộ giải mã thì giải mã lại ngay.
            BtnDecodePushed(app, []);
        end

        function BtnClearPushed(app, ~)
        %BTNCLEARPUSHED Xóa trắng ô chuỗi phím, không đụng tín hiệu đang có.
            app.EfKeys.Value = '';
        end

        function SldSNRValueChanging(app, event)
        %SLDSNRVALUECHANGING Chỉ cập nhật nhãn số dB trong lúc đang kéo.
        % KHÔNG giải mã ở đây: giải mã lại sau mỗi pixel kéo chuột làm giao
        % diện giật - việc đó để cho SldSNRValueChanged lúc thả chuột.
            hienSNR(app, event.Value);
        end

        function SldSNRValueChanged(app, ~)
        %SLDSNRVALUECHANGED Đổi SNR thì cộng lại nhiễu rồi giải mã lại ngay.
        % Dùng ValueChanged (thả chuột) chứ KHÔNG phải ValueChanging: giải mã
        % lại sau mỗi pixel kéo chuột làm giao diện giật.
            hienSNR(app, app.SldSNR.Value);
            docUI(app);
            if congNhieu(app)
                giaiMa(app);
            end
            veLai(app);
        end

    end

    methods (Access = private)

        function docUI(app)
        %DOCUI Chép giá trị ba ô điều khiển vào S. Đây là chiều UI -> S duy nhất.
        % reshape(..., 1, []) giữ luật CONTRACTS §2 "mọi giá trị rỗng là 1×0":
        % ô phím vừa bị xóa trắng trả về '' tức 0×0. dtmf_generate nhận cả hai
        % cỡ nên đây KHÔNG phải chốt chặn lỗi, nhưng S.keys đi thẳng sang
        % meta.keys rồi tới các phép so chuỗi bằng isequal, mà isequal phân
        % biệt 0×0 với 1×0 - chuẩn hóa ngay ở cửa vào là rẻ nhất.
            app.S.keys   = reshape(char(app.EfKeys.Value), 1, []);
            app.S.method = app.DdMethod.Value;
            app.S.snrDb  = app.SldSNR.Value;

            % Thanh trượt có thể bị đặt bằng code (test, make_figures) mà
            % không qua ValueChanging - nhãn dB phải khớp giá trị thật.
            hienSNR(app, app.S.snrDb);
        end

        function sinhTinHieu(app)
        %SINHTINHIEU Dựng x từ S.keys rồi cộng nhiễu thành y.
            xoaKetQua(app);
            app.S.lastError = blanks(0);

            try
                [app.S.x, ~, app.S.meta] = dtmf_generate(app.S.keys, 'fs', app.S.fs);
                app.S.y = dtmf_addnoise(app.S.x, 'snrDb', app.S.snrDb, 'fs', app.S.fs);
            catch ME
                % Ký tự lạ trong ô phím là chuyện thường ngày, không phải sự
                % cố. Xóa luôn tín hiệu cũ: giữ lại thì màn hình vẽ một dạng
                % sóng KHÔNG khớp chuỗi phím đang hiện, gây hiểu nhầm nặng.
                app.S.x    = zeros(1, 0);
                app.S.y    = zeros(1, 0);
                app.S.meta = [];
                app.S.lastError = ME.message;
            end
        end

        function ok = congNhieu(app)
        %CONGNHIEU Dựng lại y từ x theo S.snrDb, giữ nguyên x và meta.
        % Dùng khi chỉ thanh SNR đổi: sinh lại x là vô ích và làm mất đi tính
        % "cùng một tín hiệu gốc, chỉ khác mức nhiễu" của phần demo.
            xoaKetQua(app);
            app.S.lastError = blanks(0);

            try
                app.S.y = dtmf_addnoise(app.S.x, 'snrDb', app.S.snrDb, 'fs', app.S.fs);
                ok = true;
            catch ME
                app.S.y = zeros(1, 0);
                app.S.lastError = ME.message;
                ok = false;
            end
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
        %GIAIMA Chạy dtmf_run và ghi nhận là tín hiệu hiện tại đã được giải mã.
            app.S = dtmf_run(app.S);
            app.DaGiaiMa = true;
        end

        function veLai(app)
        %VELAI Vẽ lại ba trục qua ui_refresh, rồi cập nhật thẻ Kết quả.
        % Thẻ Kết quả nằm NGOÀI ui_refresh vì hợp đồng của hàm đó chỉ gồm sáu
        % thành phần (CONTRACTS §8) - test_ui_smoke dựng app giả đúng sáu thứ.
            ui_refresh(app);
            capNhatKetQua(app);
        end

        function capNhatKetQua(app)
        %CAPNHATKETQUA Ghi chuỗi đã phát và một dòng trạng thái đúng/sai.
        % Chỉ so chuỗi và đếm ký tự - không phép tính DSP nào, luật §2.
            M = ui_theme();
            S = app.S;

            daPhat = blanks(0);
            if isstruct(S.meta) && isfield(S.meta, 'keys')
                daPhat = S.meta.keys;
            end
            app.LblSent.Text = daPhat;

            % S.method lạ (test cố tình gài) thì hiện nguyên văn, không ném lỗi.
            k = find(strcmp(app.DdMethod.ItemsData, S.method), 1);
            tenPP = char(string(S.method));
            if ~isempty(k)
                tenPP = app.DdMethod.Items{k};
            end
            boi = sprintf('%s   ·   SNR %.0f dB', tenPP, S.snrDb);

            % Chấm đặc = đã có kết luận (đúng/sai), chấm rỗng = đang chờ.
            if ~isempty(S.lastError)
                txt = '●  Có lỗi, xem nhật ký';
                mau = M.sai;
            elseif isempty(S.y)
                txt = '○  Chưa có tín hiệu';
                mau = M.chuMo;
            elseif ~app.DaGiaiMa
                txt = sprintf('○  Đã phát %d phím, chưa giải mã', numel(daPhat));
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
        end

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
        % Không đi qua ui_refresh: mỗi lần bấm phím mà vẽ lại cả phổ đồ thì
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

        % ------------------------------------------------------------ dựng hình


        function dungGiaoDien(app, visible)
        %DUNGGIAODIEN Dựng cửa sổ: dòng tiêu đề trên cùng, dưới là hai cột.
        % Cột trái đi đúng thứ tự thao tác, đánh số 01-02-03: nhập phím ->
        % chọn tham số -> bấm nút -> đọc kết quả. Cột phải là ba trục của cùng
        % một tín hiệu nhìn theo ba miền: thời gian, thời gian-tần số, và một
        % khung quyết định. Màu và phông: app/ui/ui_theme.m.
            M = ui_theme();

            % 'Theme', 'light' là BẮT BUỘC, không phải sở thích. Từ R2025a
            % uifigure bám theme của hệ điều hành: máy để Windows ở chế độ tối
            % thì cả giao diện lẫn ba trục ra nền ĐEN, và ảnh chụp H3.3 của báo
            % cáo cũng đen theo. Ghim sáng để hình trên giấy, hình trên máy
            % chiếu và hình trên máy người chấm là cùng một hình.
            app.UIFigure = uifigure('Visible', visible, ...
                'Theme', 'light', ...
                'Name', 'DTMF - Phát và giải mã tín hiệu', ...
                'Position', [60 40 1280 780], ...
                'Color', M.nen, ...
                'CloseRequestFcn', @(src, evt) delete(app));

            g = uigridlayout(app.UIFigure, [2 2]);
            g.ColumnWidth     = {320, '1x'};
            g.RowHeight       = {34, '1x'};
            g.Padding         = [14 14 14 10];
            g.RowSpacing      = 12;
            g.ColumnSpacing   = 12;
            g.BackgroundColor = M.nen;

            dungTieuDe(g, M);
            dungCotTrai(app, g, M);
            dungCotPhai(app, g, M);

            % Phông chữ đặt MỘT lần cho mọi thứ có chữ, trừ những ô cố ý dùng
            % phông đơn cách (chuỗi phím, kết quả, nhật ký) - cột ký tự thẳng
            % hàng là thứ giúp so "đã phát" với "đọc được".
            h = findall(app.UIFigure, '-property', 'FontName');
            for i = 1:numel(h)
                if ~strcmp(h(i).FontName, M.fontMono)
                    h(i).FontName = M.font;
                end
            end
        end

        function dungCotTrai(app, cha, M)
        %DUNGCOTTRAI Ba thẻ đánh số theo thứ tự thao tác, nút hành động kẹp
        % giữa "tham số" và "kết quả", nhật ký lỗi nhỏ ở đáy.
            gl = uigridlayout(cha, [5 1]);
            gl.RowHeight       = {272, 122, 36, 128, '1x'};
            gl.ColumnWidth     = {'1x'};
            gl.Padding         = [0 0 0 0];
            gl.RowSpacing      = 12;
            gl.BackgroundColor = M.nen;
            gl.Layout.Row      = 2;
            gl.Layout.Column   = 1;

            % --- 01. chuỗi phím + bàn phím 4x3, kèm nhãn tần số như bảng Q.23.
            % Ô chuỗi phím nằm NGAY TRÊN bàn phím: bấm phím nào thấy ký tự
            % hiện ra ở đó, không phải liếc sang thẻ khác.
            [app.PnlKeypad, gc] = theCard(gl, '01', 'Chuỗi phím', M);
            app.PnlKeypad.Layout.Row = 1;

            kg = uigridlayout(gc, [6 4]);
            kg.RowHeight       = [{30, 14}, repmat({'1x'}, 1, 4)];
            kg.ColumnWidth     = [{30}, repmat({'1x'}, 1, 3)];
            kg.Padding         = [0 0 0 0];
            kg.RowSpacing      = 6;
            kg.ColumnSpacing   = 6;
            kg.BackgroundColor = M.the;
            kg.Layout.Row      = 2;

            app.EfKeys = uieditfield(kg, 'text', ...
                'FontName', M.fontMono, 'FontSize', 15, 'FontColor', M.muc, ...
                'Placeholder', 'vd. 0912345');
            app.EfKeys.Layout.Row = 1;  app.EfKeys.Layout.Column = [1 3];

            app.BtnClear = uibutton(kg, 'Text', 'Xóa', ...
                'FontSize', 11, 'FontColor', M.chuPhu, 'BackgroundColor', M.the, ...
                'Tooltip', 'Xóa chuỗi phím (tín hiệu đang có giữ nguyên)', ...
                'ButtonPushedFcn', @(src, evt) app.BtnClearPushed(evt));
            app.BtnClear.Layout.Row = 1;  app.BtnClear.Layout.Column = 4;

            % Tần số lấy từ bảng chứ không gõ tay - cùng lý do như ui_plot_bars.
            T = dtmf_table();
            l = uilabel(kg, 'Text', 'Hz', 'FontSize', 9, 'FontColor', M.chuMo, ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom');
            l.Layout.Row = 2;  l.Layout.Column = 1;
            for j = 1:3
                l = uilabel(kg, 'Text', sprintf('%d', T.colHz(j)), ...
                    'FontSize', 9, 'FontColor', M.chuMo, ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
                l.Layout.Row = 2;  l.Layout.Column = j + 1;
            end
            for i = 1:4
                l = uilabel(kg, 'Text', sprintf('%d', T.rowHz(i)), ...
                    'FontSize', 9, 'FontColor', M.chuMo, ...
                    'HorizontalAlignment', 'right');
                l.Layout.Row = i + 2;  l.Layout.Column = 1;
            end

            ten = {'Btn1', 'Btn2', 'Btn3', 'Btn4', 'Btn5', 'Btn6', ...
                   'Btn7', 'Btn8', 'Btn9', 'BtnStar', 'Btn0', 'BtnHash'};
            ky  = {'1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'};

            for i = 1:numel(ten)
                % '*' và '#' nền xám rất nhạt, chữ nhạt hơn: nhìn là biết phím
                % chức năng, mà không làm bàn phím loang lổ hai tông màu.
                nenPhim = M.the;
                chuPhim = M.muc;
                if any(ky{i} == '*#')
                    nenPhim = M.phimPhu;
                    chuPhim = M.chuPhu;
                end
                app.(ten{i}) = uibutton(kg, 'Text', ky{i}, ...
                    'FontSize', 18, ...
                    'FontColor', chuPhim, 'BackgroundColor', nenPhim, ...
                    'Tooltip', sprintf('%d Hz + %d Hz', ...
                        T.rowHz(ceil(i / 3)), T.colHz(mod(i - 1, 3) + 1)), ...
                    'ButtonPushedFcn', @(src, evt) app.Btn1Pushed(evt));
                app.(ten{i}).Layout.Row    = ceil(i / 3) + 2;
                app.(ten{i}).Layout.Column = mod(i - 1, 3) + 2;
            end

            % --- 02. tham số: bộ giải mã, SNR
            [pt, gc] = theCard(gl, '02', 'Tham số', M);
            pt.Layout.Row = 2;

            gt = uigridlayout(gc, [2 3]);
            gt.RowHeight       = {28, 42};
            gt.ColumnWidth     = {72, '1x', 48};
            gt.Padding         = [0 0 0 0];
            gt.RowSpacing      = 8;
            gt.ColumnSpacing   = 8;
            gt.BackgroundColor = M.the;
            gt.Layout.Row      = 2;

            nhanTinh(gt, 1, 'Bộ giải mã', M);
            app.DdMethod = uidropdown(gt, ...
                'Items',     {'FFT', 'Goertzel', 'Ngân hàng bộ lọc'}, ...
                'ItemsData', {'fft', 'goertzel', 'filterbank'}, ...
                'Value',     app.S.method, ...
                'FontColor', M.muc, 'BackgroundColor', M.the, ...
                'Tooltip', 'Đổi bộ giải mã thì giải mã lại ngay', ...
                'ValueChangedFcn', @(src, evt) app.DdMethodValueChanged(evt));
            app.DdMethod.Layout.Row = 1;  app.DdMethod.Layout.Column = [2 3];

            % Thanh trượt nằm ở mép trên hàng, vạch chia bên dưới: nhãn hai
            % bên cũng canh trên để ba thứ thẳng một đường.
            l = nhanTinh(gt, 2, 'SNR', M);
            l.VerticalAlignment = 'top';
            app.SldSNR = uislider(gt, ...
                'Limits',          [-5 30], ...
                'Value',           app.S.snrDb, ...
                'MajorTicks',      -5:5:30, ...
                'MinorTicks',      [], ...
                'FontSize',        9, ...
                'FontColor',       M.chuMo, ...
                'Tooltip', 'Thả chuột thì cộng lại nhiễu và giải mã lại', ...
                'ValueChangingFcn', @(src, evt) app.SldSNRValueChanging(evt), ...
                'ValueChangedFcn',  @(src, evt) app.SldSNRValueChanged(evt));
            app.SldSNR.Layout.Row = 2;  app.SldSNR.Layout.Column = 2;

            app.LblSNR = uilabel(gt, 'Text', blanks(0), ...
                'FontSize', 12, 'FontWeight', 'bold', 'FontColor', M.nhan, ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
            app.LblSNR.Layout.Row = 2;  app.LblSNR.Layout.Column = 3;
            hienSNR(app, app.S.snrDb);

            % --- ba nút hành động. Hai nút chính cùng họ màu tối (than, chàm)
            % theo thứ tự phát -> giải mã; "Nghe" là nút phụ nền trắng.
            gb = uigridlayout(gl, [1 3]);
            gb.Padding         = [0 0 0 0];
            gb.ColumnWidth     = {'1.1x', '1x', '0.8x'};
            gb.ColumnSpacing   = 8;
            gb.BackgroundColor = M.nen;
            gb.Layout.Row      = 3;

            app.BtnGen = uibutton(gb, 'Text', 'Phát tín hiệu', ...
                'FontSize', 12, 'FontWeight', 'bold', ...
                'FontColor', [1 1 1], 'BackgroundColor', M.muc, ...
                'Tooltip', 'Sinh tín hiệu DTMF từ chuỗi phím rồi cộng nhiễu theo SNR', ...
                'ButtonPushedFcn', @(src, evt) app.BtnGenPushed(evt));
            app.BtnDecode = uibutton(gb, 'Text', 'Giải mã', ...
                'FontSize', 12, 'FontWeight', 'bold', ...
                'FontColor', [1 1 1], 'BackgroundColor', M.nhan, ...
                'Tooltip', 'Giải mã tín hiệu bằng bộ giải mã đang chọn', ...
                'ButtonPushedFcn', @(src, evt) app.BtnDecodePushed(evt));
            app.BtnPlay = uibutton(gb, 'Text', '▶  Nghe', ...
                'FontSize', 12, ...
                'FontColor', M.muc, 'BackgroundColor', M.the, ...
                'Tooltip', 'Phát ra loa tín hiệu ĐÃ cộng nhiễu - đúng cái bộ giải mã nghe', ...
                'ButtonPushedFcn', @(src, evt) app.BtnPlayPushed(evt));

            % --- 03. kết quả: chuỗi đã phát đặt ngay trên chuỗi đọc được, cùng
            % phông đơn cách, để mắt so được từng cột ký tự. Màu chữ LblDecoded
            % (đúng xanh / sai đỏ) do ui_refresh đặt; LblSent và LblStatus do
            % capNhatKetQua đặt.
            [pk, gc] = theCard(gl, '03', 'Kết quả', M);
            pk.Layout.Row = 4;

            gk = uigridlayout(gc, [3 2]);
            gk.RowHeight       = {20, 34, 18};
            gk.ColumnWidth     = {72, '1x'};
            gk.Padding         = [0 0 0 0];
            gk.RowSpacing      = 2;
            gk.ColumnSpacing   = 8;
            gk.BackgroundColor = M.the;
            gk.Layout.Row      = 2;

            nhanTinh(gk, 1, 'Đã phát', M);
            app.LblSent = uilabel(gk, 'Text', blanks(0), ...
                'FontName', M.fontMono, 'FontSize', 15, 'FontColor', M.chuPhu);
            app.LblSent.Layout.Row = 1;  app.LblSent.Layout.Column = 2;

            nhanTinh(gk, 2, 'Đọc được', M);
            app.LblDecoded = uilabel(gk, 'Text', blanks(0), ...
                'FontName', M.fontMono, 'FontSize', 24, 'FontWeight', 'bold', ...
                'FontColor', M.muc);
            app.LblDecoded.Layout.Row = 2;  app.LblDecoded.Layout.Column = 2;

            app.LblStatus = uilabel(gk, 'Text', blanks(0), ...
                'FontSize', 11, 'FontColor', M.chuMo);
            app.LblStatus.Layout.Row = 3;  app.LblStatus.Layout.Column = [1 2];

            % --- nhật ký: chỉ ghi lỗi, nên để nhỏ, không đánh số, nằm cuối
            [pn, gc] = theCard(gl, '', 'Nhật ký lỗi', M);
            pn.Layout.Row = 5;

            app.TxtLog = uitextarea(gc, 'Editable', 'off', ...
                'FontName', M.fontMono, 'FontSize', 10, 'FontColor', M.sai, ...
                'BackgroundColor', M.the, ...
                'Placeholder', 'Chưa có lỗi nào');
            app.TxtLog.Layout.Row = 2;
        end

        function dungCotPhai(app, cha, M)
        %DUNGCOTPHAI Ba trục xếp dọc, mỗi trục một thẻ ghi rõ miền đang nhìn.
        % Trục KHÔNG nằm trong uigridlayout mà đặt tay InnerPosition với CÙNG
        % lề trái/phải (canTruc): khung vẽ của dạng sóng và phổ đồ thẳng mép
        % nhau tuyệt đối, một thời điểm trên trục này nằm đúng dưới thời điểm
        % đó trên trục kia. Trong grid, MATLAB tự co khung theo bề rộng nhãn
        % tick - '0.5' hẹp hơn '3000' - nên hai trục lệch nhau; đặt
        % PositionConstraint = 'innerposition' trong grid cũng không cứu được
        % (đo 25/09/2026: khung vẽ bị ép còn một phần ba chiều cao thẻ).
            gr = uigridlayout(cha, [3 1]);
            gr.RowHeight       = {'1x', '1.15x', '1x'};
            gr.ColumnWidth     = {'1x'};
            gr.Padding         = [0 0 0 0];
            gr.RowSpacing      = 12;
            gr.BackgroundColor = M.nen;
            gr.Layout.Row      = 2;
            gr.Layout.Column   = 2;

            so     = {'A', 'B', 'C'};
            tieuDe = {'Miền thời gian', ...
                      'Miền thời gian – tần số', ...
                      'Khung quyết định'};
            % [trái dưới phải trên] tính bằng pixel từ mép vùng vẽ của thẻ:
            % chừa chỗ cho nhãn trục và tiêu đề trục. Trục C cao hơn ở trên vì
            % có thêm một dòng phụ đề.
            le = {[58 38 6 24], [58 38 6 24], [58 38 6 40]};

            ax = cell(1, 3);
            for i = 1:3
                [p, gc] = theCard(gr, so{i}, tieuDe{i}, M);
                p.Layout.Row = i;

                % Một panel trơn làm nền cho trục. Tắt tự co giãn thì
                % SizeChangedFcn mới được gọi.
                v = uipanel(gc, 'BorderType', 'none', ...
                    'BackgroundColor', M.the, 'AutoResizeChildren', 'off');
                v.Layout.Row = 2;

                ax{i} = uiaxes(v, 'Units', 'pixels', ...
                    'PositionConstraint', 'innerposition');
                v.SizeChangedFcn = @(src, ~) canTruc(ax{i}, src, le{i});
                canTruc(ax{i}, v, le{i});
            end

            app.AxWave = ax{1};
            app.AxSpec = ax{2};
            app.AxBars = ax{3};
        end

        function hienSNR(app, v)
        %HIENSNR Ghi giá trị SNR đang chọn vào nhãn cạnh thanh trượt.
            app.LblSNR.Text = sprintf('%.0f dB', v);
        end

    end

end

function dungTieuDe(cha, M)
%DUNGTIEUDE Dòng tiêu đề: vạch nhấn, tên, và thông số hệ thống canh phải.
% Không dùng dải nền đậm: tiêu đề đứng trên nền cửa sổ như tên một bài báo,
% để phần nặng màu nhất màn hình là dữ liệu chứ không phải khung trang trí.
g = uigridlayout(cha, [1 3]);
g.ColumnWidth     = {4, 'fit', '1x'};
g.Padding         = [0 3 0 3];
g.ColumnSpacing   = 10;
g.BackgroundColor = M.nen;
g.Layout.Row      = 1;
g.Layout.Column   = [1 2];

uilabel(g, 'Text', '', 'BackgroundColor', M.nhan);
uilabel(g, 'Text', 'Phát và giải mã tín hiệu DTMF', ...
    'FontSize', 18, 'FontWeight', 'bold', 'FontColor', M.muc);
uilabel(g, 'Text', ['ITU-T Q.23     fs = 8000 Hz     ' ...
                    'FFT  ·  Goertzel  ·  Ngân hàng bộ lọc IIR'], ...
    'FontSize', 10, 'FontColor', M.chuPhu, ...
    'HorizontalAlignment', 'right');
end

function [p, g] = theCard(cha, so, tieuDe, M)
%THECARD Thẻ nền trắng viền mảnh; hàng 1 là nhãn mục, hàng 2 dành cho nội dung.
% Nhãn mục tự vẽ bằng uilabel thay cho Title của uipanel: Title luôn kèm một
% đường kẻ ngang và cỡ chữ cố định, trông như hộp thoại hơn là một mục báo cáo.
% Số mục tô màu nhấn, tên mục in hoa màu xám.
p = uipanel(cha, 'BackgroundColor', M.the, ...
    'BorderType', 'line', 'BorderColor', M.vien, 'BorderWidth', 1);

g = uigridlayout(p, [2 1]);
g.RowHeight       = {16, '1x'};
g.ColumnWidth     = {'1x'};
g.Padding         = [14 12 14 12];
g.RowSpacing      = 10;
g.BackgroundColor = M.the;

if isempty(so)
    nhan = upper(tieuDe);
else
    nhan = sprintf('<span style="color:%s">%s</span>&nbsp;&nbsp;&nbsp;%s', ...
        hex(M.nhan), so, upper(tieuDe));
end
uilabel(g, 'Text', nhan, 'Interpreter', 'html', ...
    'FontSize', 10, 'FontWeight', 'bold', 'FontColor', M.chuPhu);
end

function s = hex(rgb)
%HEX Đổi màu RGB [0..1] sang chuỗi '#RRGGBB' cho nhãn html.
s = sprintf('#%02X%02X%02X', round(255 * rgb));
end

function canTruc(ax, p, le)
%CANTRUC Đặt khung vẽ của AX cách mép trong panel P đúng LE = [trái dưới phải trên].
% Gọi lại mỗi lần panel đổi cỡ. max(..., 1): cửa sổ kéo quá nhỏ cho bề rộng
% âm, mà InnerPosition âm là lỗi.
k = p.InnerPosition;
ax.InnerPosition = [le(1), le(2), ...
                    max(k(3) - le(1) - le(3), 1), max(k(4) - le(2) - le(4), 1)];
end

function l = nhanTinh(cha, hang, nhan, M)
%NHANTINH Nhãn chú thích tĩnh ở cột 1 - không cần đặt tên, docs/ui_naming.md §1.
l = uilabel(cha, 'Text', nhan, 'FontSize', 11, 'FontColor', M.chuPhu);
l.Layout.Row    = hang;
l.Layout.Column = 1;
end
