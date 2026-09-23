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
        DdMethod    matlab.ui.control.DropDown
        SldSNR      matlab.ui.control.Slider
        BtnGen      matlab.ui.control.Button
        BtnDecode   matlab.ui.control.Button
        BtnPlay     matlab.ui.control.Button

        LblDecoded  matlab.ui.control.Label
        TxtLog      matlab.ui.control.TextArea

        % Một property trạng thái DUY NHẤT, không rải biến rời rạc. Danh sách
        % trường: docs/ui_naming.md §4.
        S           struct
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
            ui_refresh(app);
        end

        function delete(app)
        %DELETE Đóng cửa sổ khi đối tượng bị hủy.
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end

        % ------------------------------------------------------------ callback
        %
        % Cả sáu callback dưới đây để PUBLIC, khác App Designer (mặc định
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
            ui_refresh(app);
        end

        function BtnDecodePushed(app, ~)
        %BTNDECODEPUSHED Giải mã tín hiệu hiện có bằng phương pháp đang chọn.
            docUI(app);
            app.S = dtmf_run(app.S);
            ui_refresh(app);
        end

        function BtnPlayPushed(app, ~)
        %BTNPLAYPUSHED Phát tín hiệu ĐÃ CỘNG NHIỄU - đúng cái bộ giải mã nghe.
            phat(app, app.S.y);
        end

        function DdMethodValueChanged(app, ~)
        %DDMETHODVALUECHANGED Đổi bộ giải mã thì giải mã lại ngay.
            BtnDecodePushed(app, []);
        end

        function SldSNRValueChanged(app, ~)
        %SLDSNRVALUECHANGED Đổi SNR thì cộng lại nhiễu rồi giải mã lại ngay.
        % Dùng ValueChanged (thả chuột) chứ KHÔNG phải ValueChanging: giải mã
        % lại sau mỗi pixel kéo chuột làm giao diện giật.
            docUI(app);
            if congNhieu(app)
                app.S = dtmf_run(app.S);
            end
            ui_refresh(app);
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
        %DUNGGIAODIEN Dựng cửa sổ, hai cột: điều khiển bên trái, ba trục bên phải.
            % 'Theme', 'light' là BẮT BUỘC, không phải sở thích. Từ R2025a
            % uifigure bám theme của hệ điều hành: máy để Windows ở chế độ tối
            % thì cả giao diện lẫn ba trục ra nền ĐEN, và ảnh chụp H3.3 của báo
            % cáo cũng đen theo. Ghim sáng để hình trên giấy, hình trên máy
            % chiếu và hình trên máy người chấm là cùng một hình.
            app.UIFigure = uifigure('Visible', visible, ...
                'Theme', 'light', ...
                'Name', 'DTMF - Phát và giải mã tín hiệu', ...
                'Position', [80 60 1180 720], ...
                'CloseRequestFcn', @(src, evt) delete(app));

            g = uigridlayout(app.UIFigure, [1 2]);
            g.ColumnWidth = {340, '1x'};
            g.RowHeight   = {'1x'};

            dungCotTrai(app, g);
            dungCotPhai(app, g);
        end

        function dungCotTrai(app, cha)
        %DUNGCOTTRAI Bàn phím, ô phím, phương pháp, SNR, ba nút, kết quả, nhật ký.
            gl = uigridlayout(cha, [7 1]);
            gl.RowHeight    = {250, 'fit', 'fit', 70, 'fit', 'fit', '1x'};
            gl.ColumnWidth  = {'1x'};
            gl.Layout.Row    = 1;
            gl.Layout.Column = 1;

            % --- bàn phím 4x3
            app.PnlKeypad = uipanel(gl, 'Title', 'Bàn phím');
            app.PnlKeypad.Layout.Row = 1;

            kg = uigridlayout(app.PnlKeypad, [4 3]);
            kg.RowHeight   = repmat({'1x'}, 1, 4);
            kg.ColumnWidth = repmat({'1x'}, 1, 3);

            ten = {'Btn1', 'Btn2', 'Btn3', 'Btn4', 'Btn5', 'Btn6', ...
                   'Btn7', 'Btn8', 'Btn9', 'BtnStar', 'Btn0', 'BtnHash'};
            ky  = {'1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'};

            for i = 1:numel(ten)
                app.(ten{i}) = uibutton(kg, 'Text', ky{i}, 'FontSize', 18, ...
                    'ButtonPushedFcn', @(src, evt) app.Btn1Pushed(evt));
                app.(ten{i}).Layout.Row    = ceil(i / 3);
                app.(ten{i}).Layout.Column = mod(i - 1, 3) + 1;
            end

            % --- ô chuỗi phím
            r2 = hangNhan(gl, 2, 'Chuỗi phím');
            app.EfKeys = uieditfield(r2, 'text', ...
                'FontName', 'Consolas', 'FontSize', 14);

            % --- phương pháp giải mã
            r3 = hangNhan(gl, 3, 'Phương pháp');
            app.DdMethod = uidropdown(r3, ...
                'Items',     {'FFT', 'Goertzel', 'Ngân hàng bộ lọc'}, ...
                'ItemsData', {'fft', 'goertzel', 'filterbank'}, ...
                'Value',     app.S.method, ...
                'ValueChangedFcn', @(src, evt) app.DdMethodValueChanged(evt));

            % --- thanh SNR
            r4 = hangNhan(gl, 4, 'SNR (dB)');
            app.SldSNR = uislider(r4, ...
                'Limits',          [-5 30], ...
                'Value',           app.S.snrDb, ...
                'MajorTicks',      -5:5:30, ...
                'ValueChangedFcn', @(src, evt) app.SldSNRValueChanged(evt));

            % --- ba nút hành động
            gb = uigridlayout(gl, [1 3]);
            gb.Padding      = [0 0 0 0];
            gb.ColumnWidth  = {'1x', '1x', '1x'};
            gb.Layout.Row   = 5;

            app.BtnGen = uibutton(gb, 'Text', 'Phát tín hiệu', ...
                'ButtonPushedFcn', @(src, evt) app.BtnGenPushed(evt));
            app.BtnDecode = uibutton(gb, 'Text', 'Giải mã', ...
                'ButtonPushedFcn', @(src, evt) app.BtnDecodePushed(evt));
            app.BtnPlay = uibutton(gb, 'Text', 'Nghe', ...
                'ButtonPushedFcn', @(src, evt) app.BtnPlayPushed(evt));

            % --- nhãn kết quả: thứ người chấm nhìn đầu tiên
            gk = uigridlayout(gl, [1 2]);
            gk.Padding     = [0 0 0 0];
            gk.ColumnWidth = {100, '1x'};
            gk.Layout.Row  = 6;

            uilabel(gk, 'Text', 'Đọc được:');
            app.LblDecoded = uilabel(gk, 'Text', blanks(0), ...
                'FontName', 'Consolas', 'FontSize', 22, 'FontWeight', 'bold');

            % --- nhật ký
            app.TxtLog = uitextarea(gl, 'Editable', 'off');
            app.TxtLog.Layout.Row = 7;
        end

        function dungCotPhai(app, cha)
        %DUNGCOTPHAI Ba trục vẽ xếp dọc, chia đều chiều cao.
            gr = uigridlayout(cha, [3 1]);
            gr.RowHeight     = {'1x', '1x', '1x'};
            gr.ColumnWidth   = {'1x'};
            gr.Layout.Row    = 1;
            gr.Layout.Column = 2;

            app.AxWave = uiaxes(gr);
            app.AxSpec = uiaxes(gr);
            app.AxBars = uiaxes(gr);
        end

    end

end

function g = hangNhan(cha, hang, nhan)
%HANGNHAN Dựng một hàng "nhãn tĩnh bên trái, component bên phải".
% Nhãn chú thích tĩnh không cần đặt tên - docs/ui_naming.md §1.
g = uigridlayout(cha, [1 2]);
g.Padding     = [0 0 0 0];
g.ColumnWidth = {100, '1x'};
g.Layout.Row  = hang;

uilabel(g, 'Text', nhan);
end
