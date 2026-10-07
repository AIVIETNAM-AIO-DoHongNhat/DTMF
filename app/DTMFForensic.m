classdef DTMFForensic < handle
%DTMFFORENSIC Giám định ghi âm: nghe một đoạn ghi âm từ trang web, tìm lại số điện thoại đã bấm chỉ từ âm thanh
% Màn chiếu lên máy chiếu: thầy nhập số bí mật trên trang web, MATLAB đọc dần từng chữ số, kết luận, rồi mới đối chiếu với số thật
%   APP = DTMFFORENSIC() mở cửa sổ rồi tự nối đường dây tới cầu nối của trang
%   web (npm run dev hoặc npm run dev:lan trong web/). APP = DTMFFORENSIC('off')
%   dựng cửa sổ ẩn cho test: không nối mạng, không mở micro, không chạy đồng
%   hồ - test tự gọi nhanTin, nhanMau và nhip.
%
%   Một vụ đi qua bốn trạng thái (thuộc tính Ho):
%       'cho'       chờ đoạn ghi âm.
%       'nghe'      đang nhận: phím nào dtmf_listen đọc được thì hiện ngay và
%                   báo về trang.
%       'ketluan'   hết đoạn ghi âm: chạy cả ba bộ giải mã khối (dtmf_run)
%                   trên toàn bộ mẫu đã nhận, đo thời gian, gửi kết luận về
%                   trang. Chỉ từ lúc này trang mới cho công bố số thật.
%       'doichieu'  số thật đã công bố (từ trang, hoặc gõ vào ô Số thật):
%                   dtmf_judge chấm từng bộ giải mã, tô từng chữ số, vẽ làn số
%                   thật lên bản đồ 8 bin.
%
%   Nguồn âm thanh:
%       Đường dây   mẫu trang gửi qua cầu nối (DTMFLine) - đúng các mẫu trang
%                   phát ra loa. Máy của thầy mở trang qua mạng LAN.
%       Micro       MATLAB thu bằng micro. Đường dây vẫn nối thì các tin case,
%                   end, reveal của trang vẫn điều khiển vụ việc; không có
%                   trang (vd. thầy bấm số trên điện thoại thật) thì bấm Bắt
%                   đầu nghe, Kết luận, rồi gõ số thật vào ô Số thật.
%
%   Bố cục - như DTMFLive, một trang báo cáo LaTeX:
%       trái    bốn mục: 1 hồ sơ; 2 số MATLAB đọc được; 3 ba bộ giải mã;
%               4 đối chiếu
%       phải    Hình 1 cả đoạn ghi âm    |  Hình 2 cận cảnh 32 ms
%               Hình 3 năng lượng 8 bin  |  Hình 4 tám bin của một khung
%   Trục thời gian của Hình 1 và 3 tính từ đầu đoạn ghi âm (ui_live_draw với
%   V.tuyetDoi), nên đoạn ghi âm lớn dần từ trái sang phải và làn số thật
%   nằm đúng chỗ các lần bấm.
%
%   Giao diện không giải mã gì: dtmf_listen (luồng), dtmf_run (khối) và
%   dtmf_judge (đối chiếu) là ba lớp trung gian - CONTRACTS §2.
%
%   Input:
%       visible: 'on' (mặc định) hoặc 'off'.
%
%   Output:
%       app: đối tượng DTMFForensic; delete(app) ngắt dây, tắt micro, đóng cửa sổ.
%
%   Example:
%       app = DTMFForensic('off');
%       app.nhanTin(struct('t', 'case', 'id', 1, 'sec', 1.2));
%       app.nhanTin(struct('t', 'pcm', 'x', [dtmf_generate('0912'), zeros(1, 800)]));
%       app.nhanTin(struct('t', 'end'));
%       app.KetQua(1).keys                  % '0912'
%       app.nhanTin(struct('t', 'reveal', 'keys', '0912', 'marks', []));
%       app.DoiChieu(1).nDung               % 4

    properties (Access = public)
        UIFigure    matlab.ui.Figure

        % Dòng tiêu đề: nguồn, bộ giải mã, nút chính.
        BtnSrcLine  matlab.ui.control.Button
        BtnSrcMic   matlab.ui.control.Button
        DdMethod    matlab.ui.control.DropDown
        BtnRun      matlab.ui.control.Button

        % Cột trái.
        LblClock    matlab.ui.control.Label
        LblCase     matlab.ui.control.Label
        LblLine     matlab.ui.control.Label
        LblHint     matlab.ui.control.Label
        LblNumber   matlab.ui.control.Label
        LblMethods  matlab.ui.control.Label
        LblMatch    matlab.ui.control.Label
        LblVerdict  matlab.ui.control.Label
        EfTruth     matlab.ui.control.EditField
        BtnReveal   matlab.ui.control.Button

        % Bốn trục bên phải - xem ui_live_draw.
        AxWave      matlab.ui.control.UIAxes
        AxZoom      matlab.ui.control.UIAxes
        AxMap       matlab.ui.control.UIAxes
        AxBars      matlab.ui.control.UIAxes

        LblStatus   matlab.ui.control.Label
    end

    properties (Access = private)
        ChuThich    matlab.ui.control.Label     % 1×4, chú thích "Hình k:" dưới bốn trục
    end

    properties (SetAccess = private)
        % 'line' | 'mic'.
        Nguon       char = 'line'
        % 'cho' | 'nghe' | 'ketluan' | 'doichieu'.
        Ho          char = 'cho'
        % Số vụ: trang đặt (tin case), hoặc MATLAB tự đếm khi nghe micro.
        SoVu        double = 0
        % Các phím dtmf_listen đọc được trong lúc nghe vụ này.
        DaySo       char = blanks(0)
        % Toàn bộ mẫu của vụ này, cho ba bộ giải mã khối lúc kết luận.
        Y           double = zeros(1, 0)
        % Kết quả ba bộ giải mã: struct 1×3 .method .ten .keys .ms .loi.
        KetQua      struct = struct('method', {}, 'ten', {}, 'keys', {}, 'ms', {}, 'loi', {})
        % Đối chiếu từng bộ giải mã: struct 1×3 như dtmf_judge, thêm .ten.
        DoiChieu    struct = struct([])
        % Số thật và lúc bấm, cho làn trên cùng của bản đồ: .t0 .t1 .k .dung.
        That        = []
        % Đầu đường dây; test đọc Line.DaGui để biết MATLAB đã gửi gì.
        Line
        % Trạng thái bộ giải mã luồng - app/dtmf_listen.m.
        L           struct
    end

    properties (Access = private)
        Nhip                    % timer
        Mic                     % audiorecorder
        DaDoc       double = 0
        V           struct      % đối tượng đồ họa của ui_live_draw
        MocVe
        MocVu                   % tic lúc vụ bắt đầu
        MocHet                  % tic lúc trang báo hết (nguồn micro chờ thêm TRE_MIC)
        ThoiLuong   double = 0  % độ dài đoạn ghi âm trang báo trước [s]
        PhimMoi     char = blanks(0)
        MocPhim
        MatDay      logical = false
        Loi         char = blanks(0)    % lỗi gần nhất, hiện ở dòng gợi ý
    end

    properties (Constant, Access = private)
        CHU_KY      = 0.05      % chu kỳ đọc nguồn [s]
        CHU_KY_VE   = 0.1       % chu kỳ vẽ lại các trục lúc đang nghe [s]
        TRE_MIC     = 0.4       % micro: nghe thêm chừng này sau khi trang báo hết [s]
        WIN_TOI_DA  = 30        % đoạn ghi âm dài nhất [s]; micro tự kết luận khi chạm
        LAP         = 3         % số lần chạy mỗi bộ giải mã khối để đo thời gian
        PP          = {'goertzel', 'fft', 'filterbank'}
        TEN         = {'Goertzel', 'FFT', 'Ngân hàng bộ lọc'}
        TEN_NGAN    = {'Goertzel', 'FFT', 'Bộ lọc'}
    end

    methods (Access = public)

        function app = DTMFForensic(visible)
        %DTMFFORENSIC Dựng giao diện; hiện thì tự nối đường dây và chạy đồng hồ.
            if nargin < 1
                visible = 'on';
            end
            app.Line = DTMFLine();
            dungGiaoDien(app, visible);
            app.L = luongMoi(app, 10);
            capNhat(app);
            ve(app);

            if strcmp(visible, 'off')
                return
            end

            % Vẽ xong cửa sổ trước: nối dây có thể chặn ~3,4 s khi chưa có cầu
            % nối (DTMFLine).
            drawnow;
            noiDuongDay(app);
            app.Nhip = timer('Name', 'DTMFForensic', 'ExecutionMode', 'fixedSpacing', ...
                'Period', app.CHU_KY, 'BusyMode', 'drop', ...
                'TimerFcn', @(~, ~) nhip(app));
            start(app.Nhip);
        end

        function delete(app)
        %DELETE Dừng đồng hồ, tắt micro, ngắt dây, đóng cửa sổ.
            if ~isempty(app.Nhip) && isvalid(app.Nhip)
                stop(app.Nhip);
                delete(app.Nhip);
            end
            tatMic(app);
            if ~isempty(app.Line) && isvalid(app.Line)
                delete(app.Line);
            end
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end

        % ------------------------------------------------------------ callback

        function BtnSrcPushed(app, event)
        %BTNSRCPUSHED Đổi nguồn âm thanh. Đường dây vẫn nối: tin điều khiển của
        % trang (case, end, reveal) dùng được cho cả hai nguồn.
            moi = 'line';
            if event.Source == app.BtnSrcMic
                moi = 'mic';
            end
            if strcmp(moi, app.Nguon)
                return
            end
            if strcmp(app.Ho, 'nghe')
                huyVu(app, 'Đã đổi nguồn giữa chừng, vụ đang nghe bị hủy.');
            end
            app.Nguon = moi;
            kieuTab(app);
            datTieuDe(app);
            capNhat(app);
            if strcmp(moi, 'line') && ~app.Line.DaNoi && app.UIFigure.Visible == "on"
                noiDuongDay(app);
            end
        end

        function DdMethodValueChanged(app, ~)
        %DDMETHODVALUECHANGED Đổi bộ giải mã ngoài lúc nghe (lúc nghe thì bị
        % khóa): số ở mục 2 và kết luận đổi theo bộ mới; báo trang tên mới.
            chao(app);
            if strcmp(app.Ho, 'cho')
                app.L = luongMoi(app, max(app.ThoiLuong, 10));
            end
            capNhat(app);
            ve(app);
        end

        function BtnRunPushed(app, ~)
        %BTNRUNPUSHED Đường dây: nối / ngắt. Micro: bắt đầu nghe / kết luận.
            if strcmp(app.Nguon, 'line')
                if app.Line.DaNoi
                    app.Line.ngat();
                    app.MatDay = false;
                    if strcmp(app.Ho, 'nghe')
                        huyVu(app, 'Đã ngắt đường dây, vụ bị hủy.');
                    else
                        capNhat(app);
                    end
                else
                    noiDuongDay(app);
                end
            elseif strcmp(app.Ho, 'nghe')
                ketLuan(app);
            else
                batDauVu(app, app.WIN_TOI_DA, []);
            end
        end

        function BtnRevealPushed(app, ~)
        %BTNREVEALPUSHED Đối chiếu với số gõ trong ô Số thật (khi không có trang web).
            doiChieu(app, app.EfTruth.Value, []);
        end

        % --------------------------------------------- lối vào cho đồng hồ và test

        function noiDuongDay(app)
        %NOIDUONGDAY Nối tới cầu nối; được thì chào kèm tên bộ giải mã.
            M = ui_theme();
            app.LblLine.Text = '○  Đang nối đường dây…';
            app.LblLine.FontColor = M.chuPhu;
            drawnow;
            [ok, loi] = app.Line.noi();
            app.MatDay = false;
            app.Loi = blanks(0);
            if ok
                chao(app);
            else
                app.Loi = loi;
            end
            capNhat(app);
        end

        function nhip(app)
        %NHIP Một tick của đồng hồ: đọc đường dây và micro, đổi trạng thái, vẽ.
            if ~isvalid(app)
                return
            end
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                delete(app);    % cửa sổ mất mà không qua nút đóng: dọn đồng hồ, dây, micro
                return
            end
            try
                if app.Line.DaNoi
                    nhanTin(app, app.Line.doc());
                    if ~app.Line.conSong()
                        matDuongDay(app);
                    end
                end
                if strcmp(app.Nguon, 'mic')
                    docMic(app);
                    if strcmp(app.Ho, 'nghe') && ~isempty(app.MocHet) && toc(app.MocHet) >= app.TRE_MIC
                        ketLuan(app);
                    end
                end
                hoatHoa(app);
                if strcmp(app.Ho, 'nghe') && (isempty(app.MocVe) || toc(app.MocVe) >= app.CHU_KY_VE)
                    ve(app);
                end
            catch ME
                baoLoi(app, sprintf('Lỗi: %s', ME.message));
            end
        end

        function nhanTin(app, tin)
        %NHANTIN Xử lý các tin của đường dây theo đúng thứ tự đến.
        % tin: cell các struct như DTMFLine.doc trả về, hoặc một struct.
            if isstruct(tin)
                tin = {tin};
            end
            for i = 1:numel(tin)
                m = tin{i};
                switch m.t
                    case 'pcm'
                        % Nguồn micro: mẫu của trang không dùng, MATLAB tự nghe.
                        if strcmp(app.Nguon, 'line')
                            nhanMau(app, m.x);
                        end
                    case 'case'
                        sec = app.WIN_TOI_DA;
                        if isfield(m, 'sec') && isnumeric(m.sec) && isscalar(m.sec) && m.sec > 0
                            sec = double(m.sec);
                        end
                        id = [];
                        if isfield(m, 'id') && isnumeric(m.id) && isscalar(m.id)
                            id = double(m.id);
                        end
                        batDauVu(app, sec, id);
                    case 'end'
                        if strcmp(app.Nguon, 'line')
                            ketLuan(app);
                        elseif strcmp(app.Ho, 'nghe')
                            app.MocHet = tic;
                        end
                    case 'reveal'
                        marks = [];
                        if isfield(m, 'marks') && isnumeric(m.marks)
                            marks = double(reshape(m.marks, 1, []));
                        end
                        keys = blanks(0);
                        if isfield(m, 'keys')
                            keys = char(m.keys);
                        end
                        doiChieu(app, keys, marks);
                    case 'hangup'
                        % Cầu nối gửi hangup khi trang đóng hoặc tải lại.
                        if strcmp(app.Ho, 'nghe') && strcmp(app.Nguon, 'line')
                            huyVu(app, 'Trang web đã ngắt giữa chừng, vụ bị hủy.');
                        end
                end
            end
        end

        function nhanMau(app, x)
        %NHANMAU Mẫu mới của vụ đang nghe: lưu lại cho ba bộ giải mã khối, đưa
        % qua bộ giải mã luồng, báo từng phím mới. Nguồn micro gọi qua docMic;
        % test chạy ẩn gọi thẳng.
            if ~strcmp(app.Ho, 'nghe')
                return
            end
            x = reshape(double(x), 1, []);
            app.Y = [app.Y, x];
            app.L = dtmf_listen(app.L, x);
            if ~isempty(app.L.lastError)
                baoLoi(app, sprintf('Lỗi: %s', app.L.lastError));
            end
            for k = app.L.newKeys
                baoPhim(app, k);
            end
            if numel(app.Y) >= app.WIN_TOI_DA * app.L.fs
                ketLuan(app);
            end
        end

        function batDauVu(app, sec, id)
        %BATDAUVU Một đoạn ghi âm mới dài khoảng SEC giây: xóa vụ cũ, cửa sổ luồng
        % vừa đủ cả đoạn, nguồn micro thì bắt đầu ghi.
            if nargin < 3 || isempty(id)
                id = app.SoVu + 1;
            end
            tatMic(app);
            app.SoVu      = id;
            app.Ho        = 'nghe';
            app.DaySo     = blanks(0);
            app.Y         = zeros(1, 0);
            app.KetQua    = app.KetQua([]);
            app.DoiChieu  = struct([]);
            app.That      = [];
            app.ThoiLuong = min(sec, app.WIN_TOI_DA);
            app.MocVu     = tic;
            app.MocHet    = [];
            app.PhimMoi   = blanks(0);
            app.MocPhim   = [];
            app.Loi       = blanks(0);
            app.EfTruth.Value = '';
            app.L = luongMoi(app, app.ThoiLuong);
            if strcmp(app.Nguon, 'mic') && ~batMic(app)
                app.Ho = 'cho';
            end
            capNhat(app);
            ve(app);
        end

        function ketLuan(app)
        %KETLUAN Hết đoạn ghi âm: chạy cả ba bộ giải mã khối trên toàn bộ mẫu,
        % mỗi bộ LAP lần lấy thời gian nhỏ nhất, gửi kết luận về trang.
            if ~strcmp(app.Ho, 'nghe')
                return
            end
            tatMic(app);
            app.MocHet = [];
            KQ = app.KetQua([]);
            for i = 1:numel(app.PP)
                S = struct('y', app.Y, 'fs', app.L.fs, 'method', app.PP{i});
                t = Inf;
                for r = 1:app.LAP
                    t0 = tic;
                    S2 = dtmf_run(S);
                    t = min(t, toc(t0));
                end
                KQ(i) = struct('method', app.PP{i}, 'ten', app.TEN{i}, ...
                    'keys', S2.keysHat, 'ms', 1000 * t, 'loi', S2.lastError);
            end
            app.KetQua = KQ;
            app.Ho = 'ketluan';
            app.ThoiLuong = numel(app.Y) / app.L.fs;

            pp = struct('name', {KQ.ten}, 'keys', {KQ.keys}, ...
                'ms', num2cell(round([KQ.ms], 2)));
            app.Line.gui(struct('t', 'verdict', 'keys', KQ(chonPP(app)).keys, 'methods', pp));
            capNhat(app);
            ve(app);
        end

        function doiChieu(app, keys, marks)
        %DOICHIEU Số thật đã công bố: chấm cả ba bộ giải mã bằng dtmf_judge.
        % marks: [đầu1 cuối1 đầu2 ...] [s] tính từ đầu đoạn ghi âm, hoặc [].
            if strcmp(app.Ho, 'nghe')
                ketLuan(app);
            end
            if isempty(app.KetQua)
                baoLoi(app, 'Chưa có đoạn ghi âm nào để đối chiếu.');
                return
            end
            DC = struct([]);
            for i = 1:numel(app.KetQua)
                J = dtmf_judge(keys, app.KetQua(i).keys);
                if ~isempty(J.lastError)
                    baoLoi(app, sprintf('Số thật không hợp lệ: %s', J.lastError));
                    return
                end
                J.ten = app.TEN{i};
                if isempty(DC)
                    DC = J;
                else
                    DC(i) = J;
                end
            end
            app.DoiChieu = DC;
            app.Ho = 'doichieu';
            app.Loi = blanks(0);
            app.EfTruth.Value = DC(1).keysTrue;

            % Làn số thật chỉ khi mốc thời gian khớp trục: đường dây gửi đúng
            % các mẫu trang phát, còn micro bắt đầu ghi lệch với loa một chút.
            app.That = [];
            J = DC(chonPP(app));
            K = numel(J.keysTrue);
            if strcmp(app.Nguon, 'line') && numel(marks) == 2 * K && K > 0
                % Cột của align có phím thật, theo đúng thứ tự các lần bấm.
                co = J.align(1, :) ~= '-';
                app.That = struct('t0', marks(1:2:end), 't1', marks(2:2:end), ...
                    'k', J.keysTrue, 'dung', strcmp(J.op(co), 'dung'));
            end
            capNhat(app);
            ve(app);
        end

    end

    methods (Access = private)

        % ------------------------------------------------------------- vụ việc

        function L = luongMoi(app, sec)
        %LUONGMOI Bộ giải mã luồng mới, cửa sổ vừa đủ một đoạn ghi âm SEC giây.
            win = min(app.WIN_TOI_DA, max(3, sec + 0.4));
            L = dtmf_listen(struct('fs', 8000, 'method', app.DdMethod.Value, 'winSec', win));
        end

        function chao(app)
        %CHAO Báo cầu nối tên bộ giải mã và rằng đây là màn giám định.
            app.Line.gui(struct('t', 'hello', 'method', tenPP(app), 'app', 'forensic'));
        end

        function baoPhim(app, k)
        %BAOPHIM Một phím mới: thêm vào dãy số, báo trang, ghi lại để vẽ.
            app.DaySo(end+1) = k;
            app.Line.gui(struct('t', 'key', 'k', k));
            app.PhimMoi = k;
            app.MocPhim = tic;
            capNhat(app);
            ve(app);
        end

        function huyVu(app, lyDo)
        %HUYVU Bỏ vụ đang nghe, về trạng thái chờ.
            tatMic(app);
            app.Ho = 'cho';
            app.MocHet = [];
            baoLoi(app, lyDo);
        end

        function matDuongDay(app)
        %MATDUONGDAY Quá hạn không nhận được nhịp nào: cầu nối đã tắt.
            app.Line.ngat();
            app.MatDay = true;
            if strcmp(app.Ho, 'nghe') && strcmp(app.Nguon, 'line')
                huyVu(app, 'Mất đường dây giữa chừng, vụ bị hủy.');
            else
                capNhat(app);
            end
        end

        function baoLoi(app, s)
        %BAOLOI Hiện lỗi ở dòng gợi ý thay vì ném ra giữa buổi trình diễn.
            app.Loi = s;
            capNhat(app);
        end

        function i = chonPP(app)
        %CHONPP Vị trí của bộ giải mã đang chọn trong PP.
            i = find(strcmp(app.PP, app.DdMethod.Value), 1);
        end

        % ------------------------------------------------------------- micro

        function ok = batMic(app)
        %BATMIC Mở micro cho vụ vừa bắt đầu. Chạy ẩn thì không có micro thật:
        % test đưa mẫu qua nhanMau.
            app.DaDoc = 0;
            ok = true;
            if app.UIFigure.Visible == "off"
                return
            end
            [rec, loi] = ui_mic(8000);
            if isempty(rec)
                app.Loi = loi;
                ok = false;
                return
            end
            try
                record(rec);
            catch ME
                app.Loi = sprintf('Không ghi được từ micro: %s', ME.message);
                ok = false;
                return
            end
            app.Mic = rec;
        end

        function tatMic(app)
        %TATMIC Dừng micro nếu đang ghi.
            if isempty(app.Mic)
                return
            end
            try
                if isrecording(app.Mic)
                    stop(app.Mic);
                end
            catch
                % micro vừa bị rút: chỉ cần bỏ tham chiếu
            end
            app.Mic = [];
        end

        function docMic(app)
        %DOCMIC Phần mẫu micro thu được từ lần đọc trước - như DTMFLive.docMic.
            if isempty(app.Mic) || ~strcmp(app.Ho, 'nghe')
                return
            end
            y = getaudiodata(app.Mic);
            moi = y(app.DaDoc+1:end)';
            app.DaDoc = numel(y);
            nhanMau(app, moi);
        end

        % ------------------------------------------------------------- hiển thị

        function ve(app)
        %VE Vẽ một khung hình qua ui_live_draw. Đã kết luận thì Hình 2 và 4
        % xem khung rõ nhất (iSel) thay cho khung cuối, vốn là khoảng lặng.
            nho = struct('key', app.PhimMoi, 'tuoi', Inf, 'khung', 0, 'that', app.That);
            if ~isempty(app.MocPhim)
                nho.tuoi = toc(app.MocPhim);
            end
            xong = any(strcmp(app.Ho, {'ketluan', 'doichieu'}));
            if xong
                nho.khung = app.L.iSel;
            end
            app.V = ui_live_draw(app.V, app.L, nho);
            datChuThichKhung(app, xong && app.L.iSel >= 1);
            capNhatTrangThai(app);
            app.MocVe = tic;
            drawnow limitrate;
        end

        function hoatHoa(app)
        %HOATHOA Đồng hồ của vụ đang nghe; chỉ gán khi chữ đổi.
            if ~strcmp(app.Ho, 'nghe') || isempty(app.MocVu)
                return
            end
            s = dongHoVu(app);
            if ~strcmp(app.LblClock.Text, s)
                app.LblClock.Text = s;
            end
        end

        function s = dongHoVu(app)
        %DONGHOVU '04,2 / 9,8 s' lúc nghe, '9,8 s' khi xong; rỗng lúc chờ.
            switch app.Ho
                case 'nghe'
                    da = toc(app.MocVu);
                    if strcmp(app.Nguon, 'line')
                        da = numel(app.Y) / app.L.fs;
                    end
                    s = sprintf('%s / %s s', soPhay(da, '%04.1f'), soPhay(app.ThoiLuong, '%.1f'));
                    if strcmp(app.Nguon, 'mic') && app.ThoiLuong >= app.WIN_TOI_DA
                        s = sprintf('%s s', soPhay(da, '%04.1f'));
                    end
                case {'ketluan', 'doichieu'}
                    s = sprintf('%s s', soPhay(numel(app.Y) / app.L.fs, '%.1f'));
                otherwise
                    s = blanks(0);
            end
        end

        function capNhat(app)
        %CAPNHAT Mọi nhãn và nút của cột trái theo trạng thái hiện tại.
            M = ui_theme();
            nghe = strcmp(app.Ho, 'nghe');
            xong = any(strcmp(app.Ho, {'ketluan', 'doichieu'}));

            % Đường dây.
            if app.Line.DaNoi
                dong = sprintf('●  Đường dây đã nối  ·  %s:%d', app.Line.Host, app.Line.Port);
                mau = M.dung;
            elseif app.MatDay
                dong = '●  Mất đường dây  ·  bấm Nối đường dây';
                mau = M.sai;
            else
                dong = '○  Chưa nối đường dây  ·  chạy npm run dev:lan trong web/';
                mau = M.chuMo;
            end
            if strcmp(app.Nguon, 'mic')
                dong = [dong, '  ·  nghe bằng micro'];
            end
            app.LblLine.Text = dong;
            app.LblLine.FontColor = mau;

            % Hồ sơ.
            vu = blanks(0);
            if app.SoVu > 0
                vu = sprintf('Vụ %d  ·  ', app.SoVu);
            end
            switch app.Ho
                case 'cho'
                    cau = 'Đang chờ đoạn ghi âm';
                    mauCau = M.muc;
                    goiY = 'Thầy nhập số bí mật trên trang web rồi bấm Gửi cho MATLAB';
                    if strcmp(app.Nguon, 'mic')
                        goiY = 'Bấm Bắt đầu nghe, hoặc gửi đoạn ghi âm từ trang web';
                    end
                case 'nghe'
                    cau = 'Đang nghe đoạn ghi âm';
                    mauCau = M.nhan;
                    goiY = 'Chữ số hiện ngay khi MATLAB nghe ra, chưa ai biết số thật';
                case 'ketluan'
                    cau = 'Đã kết luận';
                    mauCau = M.muc;
                    goiY = 'Chờ thầy công bố số thật trên trang web';
                otherwise
                    J = app.DoiChieu(chonPP(app));
                    if J.editDist == 0
                        cau = 'Đã đối chiếu: khớp';
                        mauCau = M.dung;
                    else
                        cau = 'Đã đối chiếu: lệch';
                        mauCau = M.sai;
                    end
                    goiY = 'Gửi một đoạn ghi âm mới từ trang web để mở vụ tiếp theo';
            end
            app.LblCase.Text = [vu, cau];
            app.LblCase.FontColor = mauCau;
            if ~isempty(app.Loi)
                app.LblHint.Text = app.Loi;
                app.LblHint.FontColor = M.sai;
            else
                app.LblHint.Text = goiY;
                app.LblHint.FontColor = M.chuPhu;
            end
            app.LblClock.Text = dongHoVu(app);

            % Số MATLAB đọc được: lúc nghe là của bộ giải mã luồng; kết luận
            % rồi là của bộ giải mã khối đang chọn (luồng = khối, §7.9).
            so = app.DaySo;
            if xong
                so = app.KetQua(chonPP(app)).keys;
            end
            if isempty(so)
                so = '–';
                if nghe
                    so = '…';
                end
            end
            app.LblNumber.Text = so;
            app.LblNumber.FontColor = M.muc;
            if strcmp(app.Ho, 'doichieu')
                app.LblNumber.FontColor = mauCau;
            end

            veBang(app, M);
            veDoiChieu(app, M);

            % Nút.
            app.DdMethod.Enable = matlab.lang.OnOffSwitchState(~nghe);
            if strcmp(app.Nguon, 'line')
                app.BtnRun.Text = 'Nối đường dây';
                if app.Line.DaNoi
                    app.BtnRun.Text = 'Ngắt đường dây';
                end
            elseif nghe
                app.BtnRun.Text = 'Kết luận';
            else
                app.BtnRun.Text = 'Bắt đầu nghe';
            end
            app.BtnReveal.Enable = matlab.lang.OnOffSwitchState(xong || nghe);
            app.EfTruth.Enable = app.BtnReveal.Enable;
            capNhatTrangThai(app);
        end

        function veBang(app, M)
        %VEBANG Bảng ba bộ giải mã: tên, số đọc được, thời gian, kết quả đối
        % chiếu. Chữ đơn cách, cột căn bằng dấu cách không ngắt như DTMFLive.
            rong = [12, 21, 9];
            dong = cell(1, 3);
            for i = 1:3
                ten = toMau(pad(app.TEN_NGAN{i}, rong(1)), M.muc);
                if i == chonPP(app)
                    ten = sprintf('<b>%s</b>', ten);
                end
                so = '–';
                ms = '';
                kq = '';
                if numel(app.KetQua) >= i
                    so = app.KetQua(i).keys;
                    if isempty(so)
                        so = '(không có)';
                    end
                    ms = sprintf('%s ms', soPhay(app.KetQua(i).ms, '%.1f'));
                end
                if numel(app.DoiChieu) >= i
                    J = app.DoiChieu(i);
                    if J.editDist == 0
                        kq = toMau('đúng', M.dung);
                    else
                        kq = toMau(sprintf('lệch %d', J.editDist), M.sai);
                    end
                end
                dong{i} = [ten, toMau(pad(htmlChu(so), rong(2)), M.muc), ...
                           toMau([padTrai(ms, rong(3)), cach(3)], M.chuPhu), kq];
            end
            app.LblMethods.Text = strjoin(dong, '<br>');
        end

        function veDoiChieu(app, M)
        %VEDOICHIEU Mục 4: hai hàng chữ số căn theo align của dtmf_judge - số
        % thật, và số bộ giải mã đang chọn đọc được, tô xanh/đỏ từng chữ số.
            if ~strcmp(app.Ho, 'doichieu')
                app.LblMatch.Text = toMau('Chưa công bố số thật', M.chuMo);
                app.LblVerdict.Text = '';
                return
            end
            J = app.DoiChieu(chonPP(app));
            a = J.align;
            n = size(a, 2);
            tren = cell(1, n);
            duoi = cell(1, n);
            for q = 1:n
                % Ô trống của align ('-') hiện thành dấu chấm giữa.
                switch J.op{q}
                    case 'dung'
                        tren{q} = toMau(a(1, q), M.muc);
                        duoi{q} = toMau(a(2, q), M.dung);
                    case 'nham'
                        tren{q} = toMau(a(1, q), M.muc);
                        duoi{q} = sprintf('<u>%s</u>', toMau(a(2, q), M.sai));
                    case 'sot'
                        tren{q} = toMau(a(1, q), M.muc);
                        duoi{q} = toMau('·', M.sai);
                    otherwise
                        tren{q} = toMau('·', M.chuMo);
                        duoi{q} = sprintf('<u>%s</u>', toMau(a(2, q), M.sai));
                end
            end
            nhan = @(s) sprintf('<span style="font-size:13px">%s</span>', toMau(pad(s, 7), M.chuPhu));
            app.LblMatch.Text = [nhan('thật'), strjoin(tren, ''), '<br>', nhan('đọc'), strjoin(duoi, '')];

            if J.editDist == 0
                app.LblVerdict.Text = sprintf('%s khớp cả %d chữ số', J.ten, J.nDung);
                app.LblVerdict.FontColor = M.dung;
            else
                phan = {};
                if J.nNham > 0
                    phan{end+1} = sprintf('%d nhầm', J.nNham);
                end
                if J.nSot > 0
                    phan{end+1} = sprintf('%d sót', J.nSot);
                end
                if J.nThua > 0
                    phan{end+1} = sprintf('%d thừa', J.nThua);
                end
                app.LblVerdict.Text = sprintf('%s lệch %d: %s', J.ten, J.editDist, strjoin(phan, ', '));
                app.LblVerdict.FontColor = M.sai;
            end
        end

        function capNhatTrangThai(app)
        %CAPNHATTRANGTHAI Dòng dưới cùng: bộ giải mã và số liệu của luồng.
            L = app.L;
            nhan = nnz(strcmp(L.info.reject, 'none'));
            s = sprintf(['%s  ·  fs %d Hz  ·  đã nghe %s s  ·  %d khung  ·  ' ...
                '%d/%d khung trong đoạn ghi âm nhận ra phím'], ...
                tenPP(app), L.fs, soPhay(L.nSample / L.fs, '%.1f'), L.nFrame, ...
                nhan, numel(L.info.reject));
            if ~strcmp(app.LblStatus.Text, s)
                app.LblStatus.Text = s;
            end
        end

        function datTieuDe(app)
        %DATTIEUDE Chú thích "Hình k:" dưới bốn trục, như \caption của LaTeX.
            nguon = 'trên đường dây';
            if strcmp(app.Nguon, 'mic')
                nguon = 'thu từ micro';
            end
            cau = {sprintf('Đoạn ghi âm <i>y</i>[<i>n</i>]%s%s', cach(1), nguon), ...
                   'Cận cảnh 32 ms cuối', ...
                   ['Năng lượng 8 bin theo khung; <i>k̂</i> số đọc được, ' ...
                    '<i>k</i> số thật'], ...
                   'Tám bin của khung mới nhất'};
            for k = 1:4
                app.ChuThich(k).Text = sprintf('<b>Hình %d:%s</b>%s', k, cach(1), cau{k});
            end
        end

        function datChuThichKhung(app, ro)
        %DATCHUTHICHKHUNG Hình 2 và 4 xem khung mới nhất hay khung rõ nhất.
            if ro
                c = {'Cận cảnh 32 ms quanh khung rõ nhất', 'Tám bin của khung rõ nhất'};
            else
                c = {'Cận cảnh 32 ms cuối', 'Tám bin của khung mới nhất'};
            end
            for j = 1:2
                s = sprintf('<b>Hình %d:%s</b>%s', 2*j, cach(1), c{j});
                if ~strcmp(app.ChuThich(2*j).Text, s)
                    app.ChuThich(2*j).Text = s;
                end
            end
        end

        function s = tenPP(app)
        %TENPP Tên hiển thị của bộ giải mã đang chọn.
            s = app.TEN{chonPP(app)};
        end

        % ------------------------------------------------------------ dựng hình

        function dungGiaoDien(app, visible)
        %DUNGGIAODIEN Cửa sổ như DTMFLive: tiêu đề, đường kẻ đậm, hai cột ngăn
        % bằng một vạch mảnh, chân trang. 'Theme', 'light' bắt buộc - cùng lý
        % do như DTMFApp.
            M = ui_theme();
            app.UIFigure = uifigure('Visible', visible, ...
                'Theme', 'light', ...
                'Name', 'Giám định ghi âm DTMF - MATLAB tìm lại số điện thoại', ...
                'Icon', M.logo, ...
                'Position', viTriCuaSo(), ...
                'Color', M.the, ...
                'CloseRequestFcn', @(src, evt) delete(app));

            g = uigridlayout(app.UIFigure, [5 1]);
            g.RowHeight       = {40, 2, '1x', 1, 18};
            g.Padding         = [28 12 28 8];
            g.RowSpacing      = 10;
            g.BackgroundColor = M.the;

            dungTieuDe(app, g, M);
            ke(g, 2, 1, M.tex.ke);

            gb = uigridlayout(g, [1 3]);
            gb.ColumnWidth     = {420, 1, '1x'};
            gb.RowHeight       = {'1x'};
            gb.Padding         = [0 0 0 0];
            gb.ColumnSpacing   = 22;
            gb.BackgroundColor = M.the;
            dungCotTrai(app, gb, M);
            ke(gb, 1, 2, M.vien);
            dungTruc(app, gb, M);

            ke(g, 4, 1, M.vien);
            app.LblStatus = uilabel(g, 'Text', '', 'FontSize', 12, 'FontAngle', 'italic', ...
                'FontColor', M.chuPhu, 'HorizontalAlignment', 'center');

            h = findall(app.UIFigure, '-property', 'FontName');
            for i = 1:numel(h)
                if ~strcmp(h(i).FontName, M.tex.mono)
                    h(i).FontName = M.tex.font;
                end
            end
            datTieuDe(app);
        end

        function dungTieuDe(app, cha, M)
        %DUNGTIEUDE Tên và dòng phụ bên trái; nguồn, bộ giải mã, nút chính bên phải.
            g = uigridlayout(cha, [1 5]);
            g.ColumnWidth     = {'fit', '1x', 216, 170, 150};
            g.Padding         = [0 4 0 4];
            g.ColumnSpacing   = 10;
            g.BackgroundColor = M.the;

            uilabel(g, 'Text', 'Giám định ghi âm', 'FontSize', 24, 'FontColor', M.muc);
            uilabel(g, 'Text', 'Tìm lại số điện thoại đã bấm chỉ từ âm thanh', ...
                'FontSize', 14, 'FontAngle', 'italic', 'FontColor', M.chuPhu);

            gs = uigridlayout(g, [1 2]);
            gs.ColumnWidth     = {'1x', '1x'};
            gs.Padding         = [0 0 0 0];
            gs.ColumnSpacing   = 6;
            gs.BackgroundColor = M.the;
            app.BtnSrcLine = uibutton(gs, 'Text', 'Đường dây', 'FontSize', 14, ...
                'Tooltip', 'Trang web gửi đúng các mẫu nó phát ra loa, qua cầu nối', ...
                'ButtonPushedFcn', @(src, evt) app.BtnSrcPushed(evt));
            app.BtnSrcMic = uibutton(gs, 'Text', 'Micro', 'FontSize', 14, ...
                'Tooltip', 'MATLAB tự nghe bằng micro: loa của trang web, hoặc một điện thoại thật', ...
                'ButtonPushedFcn', @(src, evt) app.BtnSrcPushed(evt));

            app.DdMethod = uidropdown(g, ...
                'Items',     app.TEN, ...
                'ItemsData', app.PP, ...
                'Value',     'goertzel', 'FontSize', 14, ...
                'FontColor', M.muc, 'BackgroundColor', M.the, ...
                'Tooltip', 'Bộ giải mã đọc số lúc nghe và đưa ra kết luận; cả ba đều được chấm', ...
                'ValueChangedFcn', @(src, evt) app.DdMethodValueChanged(evt));

            app.BtnRun = uibutton(g, 'Text', 'Nối đường dây', 'FontSize', 14, ...
                'FontWeight', 'bold', 'FontColor', [1 1 1], 'BackgroundColor', M.muc, ...
                'ButtonPushedFcn', @(src, evt) app.BtnRunPushed(evt));
            kieuTab(app);
        end

        function dungCotTrai(app, cha, M)
        %DUNGCOTTRAI Bốn mục đánh số như \section: hồ sơ, số đọc được, ba bộ
        % giải mã (bảng kiểu booktabs), đối chiếu.
            gp = uigridlayout(cha, [17 2]);
            gp.RowHeight = {24, 30, 16, 34, 24, 50, 24, 2, 17, 1, 62, 2, 24, 64, 22, '1x', 30};
            gp.ColumnWidth     = {'1x', 'fit'};
            gp.Padding         = [0 4 0 4];
            gp.RowSpacing      = 6;
            gp.ColumnSpacing   = 8;
            gp.BackgroundColor = M.the;

            mucSo(gp, 1, 1, 'Hồ sơ', M);
            app.LblClock = uilabel(gp, 'Text', '', 'FontSize', 17, ...
                'FontColor', M.muc, 'HorizontalAlignment', 'right');
            app.LblClock.Layout.Row = 1;  app.LblClock.Layout.Column = 2;
            app.LblCase = uilabel(gp, 'Text', '', 'FontSize', 20, 'FontColor', M.muc);
            app.LblCase.Layout.Row = 2;  app.LblCase.Layout.Column = [1 2];
            app.LblLine = uilabel(gp, 'Text', '', 'FontSize', 13, 'FontColor', M.chuMo);
            app.LblLine.Layout.Row = 3;  app.LblLine.Layout.Column = [1 2];
            app.LblHint = uilabel(gp, 'Text', '', 'FontSize', 13, 'FontAngle', 'italic', ...
                'FontColor', M.chuPhu, 'WordWrap', 'on', 'VerticalAlignment', 'top');
            app.LblHint.Layout.Row = 4;  app.LblHint.Layout.Column = [1 2];

            mucSo(gp, 5, 2, 'Số MATLAB đọc được', M);
            app.LblNumber = uilabel(gp, 'Text', '', 'FontSize', 36, 'FontColor', M.muc);
            app.LblNumber.Layout.Row = 6;  app.LblNumber.Layout.Column = [1 2];

            mucSo(gp, 7, 3, 'Ba bộ giải mã', M);
            ke(gp, 8, [1 2], M.tex.ke);
            l = uilabel(gp, 'Interpreter', 'html', 'FontName', M.tex.mono, 'FontSize', 13, ...
                'FontColor', M.muc, 'Text', [pad('Bộ giải mã', 12) pad('Số đọc được', 21) ...
                padTrai('Thời gian', 9) cach(3) 'Kết quả']);
            l.Layout.Row = 9;  l.Layout.Column = [1 2];
            ke(gp, 10, [1 2], M.tex.ke);
            app.LblMethods = uilabel(gp, 'Text', '', 'Interpreter', 'html', ...
                'FontName', M.tex.mono, 'FontSize', 13, 'FontColor', M.muc, ...
                'VerticalAlignment', 'top', 'WordWrap', 'off');
            app.LblMethods.Layout.Row = 11;  app.LblMethods.Layout.Column = [1 2];
            ke(gp, 12, [1 2], M.tex.ke);

            mucSo(gp, 13, 4, 'Đối chiếu', M);
            app.LblMatch = uilabel(gp, 'Text', '', 'Interpreter', 'html', ...
                'FontName', M.tex.mono, 'FontSize', 24, 'FontColor', M.muc, ...
                'VerticalAlignment', 'top', 'WordWrap', 'off');
            app.LblMatch.Layout.Row = 14;  app.LblMatch.Layout.Column = [1 2];
            app.LblVerdict = uilabel(gp, 'Text', '', 'FontSize', 15, 'FontColor', M.muc);
            app.LblVerdict.Layout.Row = 15;  app.LblVerdict.Layout.Column = [1 2];

            gt = uigridlayout(gp, [1 2]);
            gt.Layout.Row = 17;  gt.Layout.Column = [1 2];
            gt.ColumnWidth     = {'1x', 120};
            gt.Padding         = [0 0 0 0];
            gt.ColumnSpacing   = 8;
            gt.BackgroundColor = M.the;
            app.EfTruth = uieditfield(gt, 'text', 'FontSize', 15, ...
                'FontName', M.tex.mono, 'Placeholder', 'Số thật, khi không có trang web', ...
                'Tooltip', 'Gõ số thật để đối chiếu khi nghe bằng micro mà không có trang web');
            app.BtnReveal = uibutton(gt, 'Text', 'Đối chiếu', 'FontSize', 14, ...
                'FontColor', M.muc, 'BackgroundColor', M.the, ...
                'ButtonPushedFcn', @(src, evt) app.BtnRevealPushed(evt));
        end

        function dungTruc(app, cha, M)
        %DUNGTRUC Bốn hình bên phải, như DTMFLive nhưng trục thời gian tuyệt đối
        % và không có bàn phím.
            g = uigridlayout(cha, [2 2]);
            g.ColumnWidth     = {'1.7x', '1x'};
            g.RowHeight       = {'1x', '1x'};
            g.Padding         = [0 0 0 0];
            g.RowSpacing      = 16;
            g.ColumnSpacing   = 24;
            g.BackgroundColor = M.the;

            le = [70 68 14 10];
            [app.AxWave, app.ChuThich(1)] = hinh(g, 1, 1, le, M);
            [app.AxZoom, app.ChuThich(2)] = hinh(g, 1, 2, [14 68 14 10], M);
            [app.AxMap,  app.ChuThich(3)] = hinh(g, 2, 1, le, M);
            [app.AxBars, app.ChuThich(4)] = hinh(g, 2, 2, [58 68 14 10], M);

            app.V = struct('axWave', app.AxWave, 'axZoom', app.AxZoom, ...
                'axMap', app.AxMap, 'axBars', app.AxBars, 'tuyetDoi', true);
        end

        function kieuTab(app)
        %KIEUTAB Nút nguồn đang chọn: chữ đậm trên nền xám rất nhạt, đơn sắc.
            M = ui_theme();
            chon = [strcmp(app.Nguon, 'line'), strcmp(app.Nguon, 'mic')];
            nut = [app.BtnSrcLine, app.BtnSrcMic];
            for i = 1:2
                if chon(i)
                    set(nut(i), 'FontWeight', 'bold', 'FontColor', M.muc, 'BackgroundColor', M.phimPhu);
                else
                    set(nut(i), 'FontWeight', 'normal', 'FontColor', M.chuPhu, 'BackgroundColor', M.the);
                end
            end
        end

    end

end

% ================================================================ hàm cục bộ
% viTriCuaSo, ke, mucSo, hinh, canHinh, hexMau, toMau, cach, htmlChu giống
% hàm cùng tên trong DTMFLive.m: hai màn trình bày cùng một kiểu trang LaTeX.

function pos = viTriCuaSo()
%VITRICUASO Cửa sổ 1400×860, co lại cho vừa màn hình nhỏ - như DTMFLive.
scr = get(groot, 'ScreenSize');
w = min(1400, max(1100, scr(3) - 80));
h = min(860,  max(720,  scr(4) - 110));
pos = [max(1, round((scr(3) - w) / 2)), max(40, round((scr(4) - h) / 2)), w, h];
end

function ke(g, hang, cot, mau)
%KE Một đường kẻ lấp đầy ô (hang, cot).
v = uipanel(g, 'BorderType', 'none', 'BackgroundColor', mau);
v.Layout.Row = hang;
v.Layout.Column = cot;
end

function mucSo(g, hang, so, ten, M)
%MUCSO Tên mục có số thứ tự, như \section{...} của LaTeX.
l = uilabel(g, 'Interpreter', 'html', 'FontSize', 16, 'FontColor', M.muc, ...
    'Text', sprintf('<b>%d%s%s</b>', so, cach(4), ten));
l.Layout.Row = hang;
l.Layout.Column = 1;
end

function [ax, cap] = hinh(g, hang, cot, le, M)
%HINH Một hình ở ô (hang, cot): uiaxes đặt tay InnerPosition với lề LE =
% [trái dưới phải trên], chú thích canh giữa dưới khung - như DTMFLive.
v = uipanel(g, 'BorderType', 'none', 'BackgroundColor', M.the, ...
    'AutoResizeChildren', 'off');
v.Layout.Row = hang;
v.Layout.Column = cot;
ax = uiaxes(v, 'Units', 'pixels', 'PositionConstraint', 'innerposition', ...
    'Color', M.the);
ax.Toolbar.Visible = 'off';
cap = uilabel(v, 'Text', '', 'Interpreter', 'html', 'FontSize', 13, ...
    'FontColor', M.muc, 'HorizontalAlignment', 'center');
v.SizeChangedFcn = @(src, ~) canHinh(ax, cap, src, le);
canHinh(ax, cap, v, le);
end

function canHinh(ax, cap, p, le)
%CANHINH Khung vẽ của AX cách mép trong panel P đúng LE.
k = p.InnerPosition;
w = max(k(3) - le(1) - le(3), 1);
ax.InnerPosition = [le(1), le(2), w, max(k(4) - le(2) - le(4), 1)];
cap.Position = [le(1), 2, w, 22];
end

function s = soPhay(x, dang)
%SOPHAY Số thập phân viết dấu phẩy như báo cáo: 9.8 -> '9,8'.
s = strrep(sprintf(dang, x), '.', ',');
end

function s = pad(s, n)
%PAD Thêm dấu cách không ngắt bên phải cho đủ n ký tự (cột của bảng).
s = [s, cach(max(0, n - numel(s)))];
end

function s = padTrai(s, n)
%PADTRAI Thêm dấu cách không ngắt bên trái cho đủ n ký tự (cột số canh phải).
s = [cach(max(0, n - numel(s))), s];
end

function s = hexMau(rgb)
%HEXMAU [0..1] RGB -> '#RRGGBB' cho nhãn HTML.
s = sprintf('#%02X%02X%02X', round(255 * rgb));
end

function s = toMau(chu, rgb)
%TOMAU Bọc một đoạn HTML trong span có màu chữ RGB.
s = sprintf('<span style="color:%s">%s</span>', hexMau(rgb), chu);
end

function s = cach(n)
%CACH n dấu cách không ngắt (U+00A0) - xem DTMFLive.
s = repmat(char(160), 1, n);
end

function s = htmlChu(s)
%HTMLCHU Thoát & < > để chữ thường hiện đúng trong nhãn HTML.
s = strrep(strrep(strrep(s, '&', '&amp;'), '<', '&lt;'), '>', '&gt;');
end
