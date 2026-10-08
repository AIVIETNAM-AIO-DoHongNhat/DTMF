classdef DTMFLive < handle
%DTMFLIVE Tổng đài DTMF: nghe đường dây từ trang web điện thoại (hoặc micro), giải mã và hiện từng phím ngay khi nó vang lên
% Màn trình diễn trực tiếp: bấm gọi trên trang web, MATLAB đổ chuông, nhấc máy, rồi đọc từng phím bạn bấm
%   APP = DTMFLIVE() mở cửa sổ rồi tự nối đường dây tới cầu nối của trang web
%   (npm run dev trong web/). APP = DTMFLIVE('off') dựng cửa sổ ẩn cho test:
%   không nối mạng, không mở micro, không chạy đồng hồ - test tự gọi nhanTin
%   và nhip.
%
%   Bố cục - trình bày như một trang báo cáo LaTeX (phông Times New Roman
%   của report/, số và ký hiệu Computer Modern, đường kẻ kiểu booktabs):
%       trái    bốn mục đánh số: 1 cuộc gọi (trạng thái, đồng hồ, gợi ý);
%               2 bàn phím sáng đèn; 3 dãy số MATLAB đọc được; 4 nhật ký
%       phải    Hình 1 dạng sóng 3 s gần nhất  |  Hình 2 32 ms cuối
%               Hình 3 năng lượng 8 bin        |  Hình 4 khung mới nhất
%
%   Các bước hoạt động:
%       1. Mỗi CHU_KY giây, nhip đọc nguồn đang chọn: đường dây (DTMFLine.doc)
%          hoặc micro (getaudiodata, như DTMFApp).
%       2. Tin điều khiển của đường dây đổi trạng thái cuộc gọi: 'call' -> đổ
%          chuông, GIO_CHUONG giây sau MATLAB tự nhấc máy (gửi 'answer');
%          'hangup' -> gác máy.
%       3. Âm thanh đi qua dtmf_listen - đúng bộ giải mã khối của DTMFApp và
%          của Chương 4 - nên phím hiện ở đây là phím ba bộ giải mã của đề tài
%          đọc được. Phím mới: gửi {"t":"key"} về điện thoại (menu tổng đài
%          trên trang đi theo phím này), thêm vào dãy số và nhật ký.
%       4. Vẽ lại các trục bằng ui_live_draw tối đa mỗi CHU_KY_VE giây; có phím
%          mới thì vẽ ngay để bàn phím sáng đúng lúc.
%
%   Đường dây không qua loa và micro: trang gửi chính các mẫu nó phát ra loa.
%   Vòng loa laptop -> micro laptop không đáng tin (CONTRACTS §7.9), nên khi
%   trang web và MATLAB chạy cùng máy, đường dây là cách trình diễn chính;
%   nguồn Micro dùng khi bấm số trên một điện thoại thật đặt gần micro.
%
%   Input:
%       visible: 'on' (mặc định) hoặc 'off'.
%
%   Output:
%       app: đối tượng DTMFLive; delete(app) gác máy, ngắt dây, đóng cửa sổ.
%
%   Example:
%       app = DTMFLive('off');
%       app.nhanTin(struct('t', 'call'));
%       app.nhacMay();
%       app.nhanTin(struct('t', 'pcm', 'x', dtmf_generate('59')));
%       app.LblNumber.Text      % '59'

    properties (Access = public)
        UIFigure    matlab.ui.Figure

        % Dòng tiêu đề: nguồn, bộ giải mã, nút nối/ngắt (hoặc bật/tắt micro).
        BtnSrcLine  matlab.ui.control.Button
        BtnSrcMic   matlab.ui.control.Button
        DdMethod    matlab.ui.control.DropDown
        BtnRun      matlab.ui.control.Button

        % Thẻ cuộc gọi bên trái.
        LblLine     matlab.ui.control.Label
        LblCall     matlab.ui.control.Label
        LblClock    matlab.ui.control.Label
        LblHint     matlab.ui.control.Label
        AxPad       matlab.ui.control.UIAxes
        LblNumber   matlab.ui.control.Label
        LnkClear    matlab.ui.control.Hyperlink
        LblLog      matlab.ui.control.Label
        BtnHangup   matlab.ui.control.Button

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
        % Nguồn đường dây: 'cho' | 'chuong' | 'noi' | 'xong'.
        % Nguồn micro:     'tat' | 'nghe'.
        CuocGoi     char = 'cho'
        % Các phím đã đọc được trong cuộc gọi (hoặc lượt nghe micro) này.
        DaySo       char = blanks(0)
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
        MocChuong
        MocNoi
        ThoiLuong   double = 0
        PhimMoi     char = blanks(0)
        MocPhim
        MatDay      logical = false     % vừa mất đường dây (để báo khác "chưa nối")
        NhatKy      cell = {}           % các dòng nhật ký, đã ở dạng HTML
        MauCall                         % màu chữ LblCall đang đặt, để khỏi gán lại
    end

    properties (Constant, Access = private)
        CHU_KY      = 0.05      % chu kỳ đọc nguồn [s]
        CHU_KY_VE   = 0.1       % chu kỳ vẽ lại các trục [s]
        GIO_CHUONG  = 1.5       % đổ chuông bao lâu rồi MATLAB nhấc máy [s]
        NGHE_TOI_DA = 120       % micro: ghi lại từ đầu sau chừng này giây [s]
        SO_HIEN     = 16        % số phím cuối hiện trên LblNumber
        SO_DONG     = 6         % số dòng nhật ký mới nhất hiện trên LblLog
    end

    methods (Access = public)

        function app = DTMFLive(visible)
        %DTMFLIVE Dựng giao diện; hiện thì tự nối đường dây và chạy đồng hồ.
            if nargin < 1
                visible = 'on';
            end
            app.Line = DTMFLine();
            dungGiaoDien(app, visible);
            app.L = luongMoi(app);
            capNhatNhan(app);
            ve(app);

            if strcmp(visible, 'off')
                return
            end

            % Vẽ xong cửa sổ trước: nối dây có thể chặn ~3,4 s khi chưa có cầu
            % nối (DTMFLine), không để người dùng nhìn một khung trắng.
            drawnow;
            noiDuongDay(app);
            app.Nhip = timer('Name', 'DTMFLive', 'ExecutionMode', 'fixedSpacing', ...
                'Period', app.CHU_KY, 'BusyMode', 'drop', ...
                'TimerFcn', @(~, ~) nhip(app));
            start(app.Nhip);
        end

        function delete(app)
        %DELETE Gác máy, ngắt dây, tắt micro, dừng đồng hồ, đóng cửa sổ.
            if ~isempty(app.Nhip) && isvalid(app.Nhip)
                stop(app.Nhip);
                delete(app.Nhip);
            end
            tatMic(app);
            if ~isempty(app.Line) && isvalid(app.Line)
                gacMay(app, true);
                delete(app.Line);
            end
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end

        % ------------------------------------------------------------ callback

        function BtnSrcPushed(app, event)
        %BTNSRCPUSHED Đổi nguồn: đường dây <-> micro. Bấm lại nguồn đang chọn thì thôi.
            moi = 'line';
            if event.Source == app.BtnSrcMic
                moi = 'mic';
            end
            if strcmp(moi, app.Nguon)
                return
            end

            % Rời đường dây thì ngắt hẳn: không đọc mà vẫn nối thì cầu nối dồn
            % tin lại, và trang web tưởng MATLAB vẫn đang làm tổng đài.
            if strcmp(app.Nguon, 'line')
                gacMay(app, true);
                app.Line.ngat();
                app.CuocGoi = 'tat';
            else
                tatMic(app);
                app.CuocGoi = 'cho';
            end
            app.Nguon = moi;
            app.MatDay = false;
            kieuTab(app);
            app.L = luongMoi(app);
            app.DaySo = blanks(0);
            app.NhatKy = {};
            datTieuDe(app);
            capNhatNhan(app);
            ve(app);
            if strcmp(moi, 'line') && app.UIFigure.Visible == "on"
                noiDuongDay(app);
            end
        end

        function DdMethodValueChanged(app, ~)
        %DDMETHODVALUECHANGED Đổi bộ giải mã giữa chừng: giữ các phím đã đọc,
        % dựng lại luồng - khung dở của phương pháp cũ chia khung khác.
            app.L = dtmf_listen(struct('fs', 8000, 'method', app.DdMethod.Value, ...
                'keysHat', app.L.keysHat));
            chao(app);
            capNhatNhan(app);
            ve(app);
        end

        function BtnRunPushed(app, ~)
        %BTNRUNPUSHED Đường dây: nối / ngắt. Micro: bật / tắt.
            if strcmp(app.Nguon, 'line')
                if app.Line.DaNoi
                    gacMay(app, true);
                    app.Line.ngat();
                    app.MatDay = false;
                    capNhatNhan(app);
                else
                    noiDuongDay(app);
                end
            elseif strcmp(app.CuocGoi, 'nghe')
                tatMic(app);
                app.CuocGoi = 'tat';
                capNhatNhan(app);
            else
                batMic(app);
            end
        end

        function BtnHangupPushed(app, ~)
        %BTNHANGUPPUSHED MATLAB gác máy: báo điện thoại rồi kết thúc cuộc gọi.
            gacMay(app, true);
        end

        function LnkClearClicked(app, ~)
        %LNKCLEARCLICKED Xóa dãy số và nhật ký đang hiện, không đụng cuộc gọi.
            app.DaySo = blanks(0);
            app.NhatKy = {};
            capNhatNhan(app);
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
            if ok
                chao(app);
                app.CuocGoi = 'cho';
                ghiNhatKy(app, sprintf('Đã nối đường dây %s:%d', app.Line.Host, app.Line.Port));
            else
                ghiNhatKy(app, loi, 'loi');
            end
            capNhatNhan(app);
        end

        function nhip(app)
        %NHIP Một tick của đồng hồ: đọc nguồn, đổi trạng thái, vẽ.
            if ~isvalid(app)
                return
            end
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                delete(app);    % cửa sổ mất mà không qua nút đóng: dọn đồng hồ, dây, micro
                return
            end
            try
                if strcmp(app.Nguon, 'line')
                    if app.Line.DaNoi
                        % Xét còn sống NGAY sau khi đọc, trước khi xử lý tin: kết luận ba bộ
                        % giải mã có thể tốn cả giây, tính cả thời gian đó là báo nhầm mất dây.
                        tin = app.Line.doc();
                        if app.Line.conSong()
                            nhanTin(app, tin);
                        else
                            matDuongDay(app);
                        end
                    end
                    if strcmp(app.CuocGoi, 'chuong') && toc(app.MocChuong) >= app.GIO_CHUONG
                        nhacMay(app);
                    end
                else
                    docMic(app);
                end
                hoatHoa(app);
                if isempty(app.MocVe) || toc(app.MocVe) >= app.CHU_KY_VE
                    ve(app);
                end
            catch ME
                ghiNhatKy(app, sprintf('Lỗi: %s', ME.message), 'loi');
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
                        nhanMau(app, m.x);
                    case 'call'
                        coCuocGoi(app);
                    case 'hangup'
                        gacMay(app, false);
                end
            end
        end

        function nhacMay(app)
        %NHACMAY MATLAB nhấc máy: báo điện thoại, đồng hồ cuộc gọi bắt đầu chạy.
            if ~strcmp(app.CuocGoi, 'chuong')
                return
            end
            app.Line.gui(struct('t', 'answer'));
            app.CuocGoi = 'noi';
            app.MocNoi = tic;
            ghiNhatKy(app, 'Đã nhấc máy');
            capNhatNhan(app);
        end

    end

    methods (Access = private)

        % ----------------------------------------------------- cuộc gọi, âm thanh

        function L = luongMoi(app)
        %LUONGMOI Bộ giải mã luồng mới theo phương pháp đang chọn.
            L = dtmf_listen(struct('fs', 8000, 'method', app.DdMethod.Value));
        end

        function chao(app)
        %CHAO Báo cầu nối tên bộ giải mã; trang web hiện nó trên thẻ danh bạ.
            app.Line.gui(struct('t', 'hello', 'method', tenPP(app), 'app', 'live'));
        end

        function coCuocGoi(app)
        %COCUOCGOI Điện thoại gọi tới: luồng mới, dãy số mới, bắt đầu đổ chuông.
            if ~strcmp(app.Nguon, 'line')
                return
            end
            app.L = luongMoi(app);
            app.DaySo = blanks(0);
            app.NhatKy = {};
            app.PhimMoi = blanks(0);
            app.CuocGoi = 'chuong';
            app.MocChuong = tic;
            ghiNhatKy(app, 'Cuộc gọi đến');
            capNhatNhan(app);
            ve(app);
        end

        function gacMay(app, baoDienThoai)
        %GACMAY Kết thúc cuộc gọi; baoDienThoai = true khi chính MATLAB gác máy.
            if ~(strcmp(app.CuocGoi, 'chuong') || strcmp(app.CuocGoi, 'noi'))
                return
            end
            if baoDienThoai
                app.Line.gui(struct('t', 'hangup'));
            end
            app.ThoiLuong = 0;
            if strcmp(app.CuocGoi, 'noi')
                app.ThoiLuong = toc(app.MocNoi);
            end
            app.CuocGoi = 'xong';
            ghiNhatKy(app, 'Đã gác máy');
            capNhatNhan(app);
        end

        function matDuongDay(app)
        %MATDUONGDAY Quá hạn không nhận được nhịp nào: cầu nối đã tắt.
            app.Line.ngat();
            gacMay(app, false);
            app.MatDay = true;
            ghiNhatKy(app, 'Mất đường dây: cầu nối không còn trả lời', 'loi');
            capNhatNhan(app);
        end

        function nhanMau(app, x)
        %NHANMAU Đưa mẫu vào bộ giải mã luồng; báo từng phím mới.
            app.L = dtmf_listen(app.L, x);
            if ~isempty(app.L.lastError)
                ghiNhatKy(app, sprintf('Lỗi: %s', app.L.lastError), 'loi');
            end
            for k = app.L.newKeys
                baoPhim(app, k);
            end
        end

        function baoPhim(app, k)
        %BAOPHIM Một phím mới: gửi điện thoại, thêm vào dãy số, sáng bàn phím.
        % Phím nghe được khi chưa nhấc máy (lúc đổ chuông) không tính: điện
        % thoại chưa vào menu nào để nhận nó.
            if strcmp(app.Nguon, 'line') && ~strcmp(app.CuocGoi, 'noi')
                return
            end
            if strcmp(app.Nguon, 'line')
                app.Line.gui(struct('t', 'key', 'k', k));
            end
            app.DaySo(end+1) = k;
            app.PhimMoi = k;
            app.MocPhim = tic;

            T = dtmf_table();
            rc = T.map(k);
            moc = 0;
            if ~isempty(app.MocNoi)
                moc = toc(app.MocNoi);
            end
            M = ui_theme();
            % Cột thẳng hàng với hàng tiêu đề 'Lúc  Phím  Tần số (Hz)' của bảng.
            themDong(app, [toMau([dongHo(moc, true), cach(3)], M.chuMo), ...
                sprintf('<b style="color:%s">%s</b>', hexMau(M.nhan), htmlChu(k)), ...
                toMau([cach(6), sprintf('%d + %d', T.rowHz(rc(1)), T.colHz(rc(2)))], M.chuPhu)]);
            capNhatNhan(app);
            ve(app);
        end

        % ------------------------------------------------------------- micro

        function batMic(app)
        %BATMIC Mở micro, luồng mới; tick đọc mẫu qua docMic.
            app.L = luongMoi(app);
            app.DaySo = blanks(0);
            app.NhatKy = {};
            app.DaDoc = 0;
            if app.UIFigure.Visible == "off"
                app.CuocGoi = 'nghe';
                app.MocNoi = tic;
                capNhatNhan(app);
                return
            end
            [rec, loi] = ui_mic(8000);
            if isempty(rec)
                ghiNhatKy(app, loi, 'loi');
                capNhatNhan(app);
                return
            end
            try
                record(rec);
            catch ME
                ghiNhatKy(app, sprintf('Không ghi được từ micro: %s', ME.message), 'loi');
                return
            end
            app.Mic = rec;
            app.CuocGoi = 'nghe';
            app.MocNoi = tic;
            ghiNhatKy(app, 'Bật micro');
            capNhatNhan(app);
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
        %DOCMIC Lấy phần mẫu micro thu được từ lần đọc trước - như DTMFApp.docMic.
            if isempty(app.Mic) || ~strcmp(app.CuocGoi, 'nghe')
                return
            end
            y = getaudiodata(app.Mic);
            moi = y(app.DaDoc+1:end)';
            app.DaDoc = numel(y);
            nhanMau(app, moi);
            % getaudiodata trả CẢ bản ghi: ghi lại từ đầu khi quá dài, chọn
            % lúc không có phím nào đang kêu.
            if app.DaDoc > app.NGHE_TOI_DA * 8000 && app.L.runLen == 0
                stop(app.Mic);
                record(app.Mic);
                app.DaDoc = 0;
            end
        end

        % ------------------------------------------------------------- hiển thị

        function ve(app)
        %VE Vẽ một khung hình qua ui_live_draw.
            nho = struct('key', app.PhimMoi, 'tuoi', Inf);
            if ~isempty(app.MocPhim)
                nho.tuoi = toc(app.MocPhim);
            end
            app.V = ui_live_draw(app.V, app.L, nho);
            capNhatTrangThai(app);
            app.MocVe = tic;
            drawnow limitrate;
        end

        function hoatHoa(app)
        %HOATHOA Những thứ đổi theo thời gian mà không cần vẽ trục: đồng hồ
        % cuộc gọi và chữ trạng thái nhấp nháy nhẹ lúc đổ chuông. Chỉ gán khi
        % giá trị đổi.
            M = ui_theme();
            mau = app.MauCall;
            switch app.CuocGoi
                case 'chuong'
                    mau = M.nhan;
                    if mod(toc(app.MocChuong), 0.8) >= 0.4
                        mau = 0.45 * M.nhan + 0.55 * M.the;
                    end
                case {'noi', 'nghe'}
                    s = dongHo(toc(app.MocNoi), false);
                    if ~strcmp(app.LblClock.Text, s)
                        app.LblClock.Text = s;
                    end
            end
            if ~isequal(app.MauCall, mau)
                app.LblCall.FontColor = mau;
                app.MauCall = mau;
            end
        end

        function capNhatNhan(app)
        %CAPNHATNHAN Các nhãn của thẻ cuộc gọi và nút theo trạng thái hiện tại.
            M = ui_theme();

            if strcmp(app.Nguon, 'line')
                if app.Line.DaNoi
                    dong = sprintf('●  Đã nối  ·  %s:%d', app.Line.Host, app.Line.Port);
                    mau = M.dung;
                elseif app.MatDay
                    dong = '●  Mất đường dây  ·  bấm Nối đường dây';
                    mau = M.sai;
                else
                    dong = '○  Chưa nối  ·  chạy npm run dev trong web/';
                    mau = M.chuMo;
                end
                app.BtnRun.Text = 'Nối đường dây';
                if app.Line.DaNoi
                    app.BtnRun.Text = 'Ngắt đường dây';
                end
            else
                if strcmp(app.CuocGoi, 'nghe')
                    dong = '●  Micro đang nghe';
                    mau = M.nhan;
                    app.BtnRun.Text = 'Tắt micro';
                else
                    dong = '○  Micro đang tắt';
                    mau = M.chuMo;
                    app.BtnRun.Text = 'Bật micro';
                end
            end
            app.LblLine.Text = dong;
            app.LblLine.FontColor = mau;

            % goi: trạng thái lớn; gio: đồng hồ bên phải; goiY: dòng gợi ý.
            gio = blanks(0);
            switch app.CuocGoi
                case 'cho'
                    goi = 'Đang chờ cuộc gọi';
                    goiY = 'Mở trang web điện thoại và bấm gọi';
                    mauGoi = M.muc;
                case 'chuong'
                    goi = 'Cuộc gọi đến';
                    goiY = strrep(sprintf('MATLAB tự nhấc máy sau %.1f s', app.GIO_CHUONG), '.', ',');
                    mauGoi = M.nhan;
                case 'noi'
                    goi = 'Đang nghe máy';
                    gio = dongHo(toc(app.MocNoi), false);
                    goiY = 'Bấm số trên trang web, phím hiện ngay khi vang lên';
                    mauGoi = M.dung;
                case 'xong'
                    goi = 'Đã gác máy';
                    gio = sprintf('%s · %d phím', dongHo(app.ThoiLuong, false), numel(app.DaySo));
                    goiY = 'Bấm gọi lại trên trang web để bắt đầu cuộc mới';
                    mauGoi = M.chuPhu;
                case 'nghe'
                    goi = 'Đang nghe micro';
                    gio = dongHo(toc(app.MocNoi), false);
                    goiY = 'Bấm số trên điện thoại đặt cách micro 5–10 cm';
                    mauGoi = M.nhan;
                otherwise
                    goi = 'Micro đang tắt';
                    goiY = 'Bấm Bật micro, đặt điện thoại cách 5–10 cm';
                    mauGoi = M.chuPhu;
            end
            app.LblCall.Text = goi;
            app.LblCall.FontColor = mauGoi;
            app.MauCall = mauGoi;
            app.LblClock.Text = gio;
            app.LblHint.Text = goiY;

            app.BtnHangup.Enable = matlab.lang.OnOffSwitchState( ...
                strcmp(app.CuocGoi, 'chuong') || strcmp(app.CuocGoi, 'noi'));

            % Dãy số: chỉ SO_HIEN phím cuối cho vừa nhãn; đủ cả dãy ở nhật ký.
            so = app.DaySo;
            if numel(so) > app.SO_HIEN
                so = ['…', so(end-app.SO_HIEN+1:end)];
            end
            app.LblNumber.Text = so;

            veNhatKy(app);
            capNhatTrangThai(app);
        end

        function capNhatTrangThai(app)
        %CAPNHATTRANGTHAI Dòng dưới cùng: bộ giải mã và số liệu của luồng.
            L = app.L;
            nhan = nnz(strcmp(L.info.reject, 'none'));
            s = sprintf(['%s  ·  fs %d Hz  ·  đã nghe %.1f s  ·  %d khung  ·  ' ...
                '%d/%d khung trong %g s cuối nhận ra phím'], ...
                tenPP(app), L.fs, L.nSample / L.fs, L.nFrame, ...
                nhan, numel(L.info.reject), L.winSec);
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
            cau = {sprintf('Tín hiệu <i>y</i>[<i>n</i>]%s%s trong 3 s gần nhất', cach(1), nguon), ...
                   'Cận cảnh 32 ms cuối, tổng của hai sóng sin', ...
                   'Năng lượng 8 bin theo khung, thang màu 0 – 0,5', ...
                   'Tám bin của khung mới nhất'};
            for k = 1:4
                app.ChuThich(k).Text = sprintf('<b>Hình %d:%s</b>%s', k, cach(1), cau{k});
            end
        end

        function ghiNhatKy(app, dong, kieu)
        %GHINHATKY Thêm một dòng sự kiện vào nhật ký; kieu = 'loi' tô màu sai.
        % Cột thời điểm là đồng hồ cuộc gọi nếu đang trong cuộc, không thì gạch.
            M = ui_theme();
            mau = M.chuPhu;
            if nargin >= 3 && strcmp(kieu, 'loi')
                mau = M.sai;
            end
            moc = [cach(3) '–' cach(3)];
            if any(strcmp(app.CuocGoi, {'noi', 'nghe'})) && ~isempty(app.MocNoi)
                moc = dongHo(toc(app.MocNoi), true);
            end
            themDong(app, [toMau([moc, cach(3)], M.chuMo), toMau(htmlChu(dong), mau)]);
        end

        function themDong(app, html)
        %THEMDONG Thêm một dòng HTML vào nhật ký; giữ 200 dòng gần nhất.
            app.NhatKy{end+1} = html;
            if numel(app.NhatKy) > 200
                app.NhatKy = app.NhatKy(end-199:end);
            end
            veNhatKy(app);
        end

        function veNhatKy(app)
        %VENHATKY SO_DONG dòng mới nhất lên LblLog, mới nhất ở trên.
            if isempty(app.NhatKy)
                M = ui_theme();
                s = toMau('chưa có sự kiện nào', M.chuMo);
            else
                s = strjoin(app.NhatKy(end:-1:max(1, end-app.SO_DONG+1)), '<br>');
            end
            if ~strcmp(app.LblLog.Text, s)
                app.LblLog.Text = s;
            end
        end

        function s = tenPP(app)
        %TENPP Tên hiển thị của bộ giải mã đang chọn.
            k = find(strcmp(app.DdMethod.ItemsData, app.DdMethod.Value), 1);
            s = app.DdMethod.Items{k};
        end

        % ------------------------------------------------------------ dựng hình

        function dungGiaoDien(app, visible)
        %DUNGGIAODIEN Cửa sổ trình bày như một trang LaTeX: tiêu đề, đường kẻ
        % đậm, hai cột ngăn bằng một vạch mảnh, chân trang.
        % 'Theme', 'light' bắt buộc - cùng lý do như DTMFApp.
            M = ui_theme();
            app.UIFigure = uifigure('Visible', visible, ...
                'Theme', 'light', ...
                'Name', 'Tổng đài DTMF - MATLAB nghe và giải mã', ...
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
            gb.ColumnWidth     = {360, 1, '1x'};
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
        %DUNGTIEUDE Tên và dòng phụ nghiêng bên trái; nguồn, bộ giải mã và nút
        % chính bên phải, cùng cao 32 px. Nút chọn và nút chính đơn sắc.
            g = uigridlayout(cha, [1 5]);
            g.ColumnWidth     = {'fit', '1x', 216, 170, 150};
            g.Padding         = [0 4 0 4];
            g.ColumnSpacing   = 10;
            g.BackgroundColor = M.the;

            uilabel(g, 'Text', 'Tổng đài DTMF', 'FontSize', 24, 'FontColor', M.muc);
            uilabel(g, 'Text', 'MATLAB nghe đường dây và giải mã từng phím', ...
                'FontSize', 14, 'FontAngle', 'italic', 'FontColor', M.chuPhu);

            gs = uigridlayout(g, [1 2]);
            gs.ColumnWidth     = {'1x', '1x'};
            gs.Padding         = [0 0 0 0];
            gs.ColumnSpacing   = 6;
            gs.BackgroundColor = M.the;
            app.BtnSrcLine = uibutton(gs, 'Text', 'Đường dây', 'FontSize', 14, ...
                'Tooltip', 'Trang web gửi thẳng tiếng nó phát ra loa qua cầu nối (npm run dev)', ...
                'ButtonPushedFcn', @(src, evt) app.BtnSrcPushed(evt));
            app.BtnSrcMic = uibutton(gs, 'Text', 'Micro', 'FontSize', 14, ...
                'Tooltip', 'Nghe qua micro, vd. bấm số trên một điện thoại thật', ...
                'ButtonPushedFcn', @(src, evt) app.BtnSrcPushed(evt));

            app.DdMethod = uidropdown(g, ...
                'Items',     {'Goertzel', 'FFT', 'Ngân hàng bộ lọc'}, ...
                'ItemsData', {'goertzel', 'fft', 'filterbank'}, ...
                'Value',     'goertzel', 'FontSize', 14, ...
                'FontColor', M.muc, 'BackgroundColor', M.the, ...
                'Tooltip', 'Bộ giải mã; đổi giữa chừng vẫn giữ các phím đã đọc', ...
                'ValueChangedFcn', @(src, evt) app.DdMethodValueChanged(evt));

            app.BtnRun = uibutton(g, 'Text', 'Nối đường dây', 'FontSize', 14, ...
                'FontWeight', 'bold', 'FontColor', [1 1 1], 'BackgroundColor', M.muc, ...
                'ButtonPushedFcn', @(src, evt) app.BtnRunPushed(evt));
            kieuTab(app);
        end

        function dungCotTrai(app, cha, M)
        %DUNGCOTTRAI Cột trái chia bốn mục đánh số như \section: cuộc gọi, bàn
        % phím, dãy số, nhật ký. Nhật ký là một bảng kiểu booktabs: kẻ đậm trên
        % và dưới, kẻ mảnh dưới hàng tiêu đề.
            gp = uigridlayout(cha, [15 2]);
            gp.RowHeight       = {24, 26, 16, 16, 24, '1x', 24, 40, 24, 2, 16, 1, 92, 2, 30};
            gp.ColumnWidth     = {'1x', 'fit'};
            gp.Padding         = [0 4 0 4];
            gp.RowSpacing      = 6;
            gp.ColumnSpacing   = 8;
            gp.BackgroundColor = M.the;

            mucSo(gp, 1, 1, 'Cuộc gọi', M);
            app.LblClock = uilabel(gp, 'Text', '', 'FontSize', 17, ...
                'FontColor', M.muc, 'HorizontalAlignment', 'right');
            app.LblClock.Layout.Row = 1;  app.LblClock.Layout.Column = 2;

            app.LblCall = uilabel(gp, 'Text', '', 'FontSize', 20, 'FontColor', M.muc);
            app.LblCall.Layout.Row = 2;  app.LblCall.Layout.Column = [1 2];
            app.LblLine = uilabel(gp, 'Text', '', 'FontSize', 13, 'FontColor', M.chuMo);
            app.LblLine.Layout.Row = 3;  app.LblLine.Layout.Column = [1 2];
            app.LblHint = uilabel(gp, 'Text', '', 'FontSize', 13, 'FontAngle', 'italic', ...
                'FontColor', M.chuPhu);
            app.LblHint.Layout.Row = 4;  app.LblHint.Layout.Column = [1 2];

            mucSo(gp, 5, 2, 'Bàn phím', M);
            v = uipanel(gp, 'BorderType', 'none', 'BackgroundColor', M.the, ...
                'AutoResizeChildren', 'off');
            v.Layout.Row = 6;  v.Layout.Column = [1 2];
            app.AxPad = uiaxes(v, 'Units', 'pixels', 'Color', M.the);
            app.AxPad.Toolbar.Visible = 'off';
            v.SizeChangedFcn = @(src, ~) coBanPhim(app, src);
            app.AxPad.Position = [0 0 v.InnerPosition(3:4)];

            mucSo(gp, 7, 3, 'Dãy số đọc được', M);
            app.LnkClear = uihyperlink(gp, 'Text', 'xóa', 'FontSize', 14, ...
                'FontColor', M.nhan, 'VisitedColor', M.nhan, ...
                'HorizontalAlignment', 'right', ...
                'Tooltip', 'Xóa dãy số và nhật ký đang hiện, cuộc gọi vẫn giữ nguyên', ...
                'HyperlinkClickedFcn', @(src, evt) app.LnkClearClicked(evt));
            app.LnkClear.Layout.Row = 7;  app.LnkClear.Layout.Column = 2;
            app.LblNumber = uilabel(gp, 'Text', '', 'FontSize', 32, 'FontColor', M.muc);
            app.LblNumber.Layout.Row = 8;  app.LblNumber.Layout.Column = [1 2];

            mucSo(gp, 9, 4, 'Nhật ký', M);
            ke(gp, 10, [1 2], M.tex.ke);
            l = uilabel(gp, 'Interpreter', 'html', 'FontName', M.tex.mono, 'FontSize', 12, ...
                'FontColor', M.muc, 'Text', ['Lúc' cach(7) 'Phím' cach(3) 'Tần số (Hz)']);
            l.Layout.Row = 11;  l.Layout.Column = [1 2];
            ke(gp, 12, [1 2], M.tex.ke);
            app.LblLog = uilabel(gp, 'Text', '', 'Interpreter', 'html', ...
                'FontName', M.tex.mono, 'FontSize', 12, 'FontColor', M.chuPhu, ...
                'VerticalAlignment', 'top', 'WordWrap', 'off');
            app.LblLog.Layout.Row = 13;  app.LblLog.Layout.Column = [1 2];
            ke(gp, 14, [1 2], M.tex.ke);

            app.BtnHangup = uibutton(gp, 'Text', 'Gác máy', 'FontSize', 14, ...
                'FontColor', M.sai, 'BackgroundColor', M.the, 'Enable', 'off', ...
                'Tooltip', 'MATLAB kết thúc cuộc gọi; điện thoại trên trang cũng gác máy', ...
                'ButtonPushedFcn', @(src, evt) app.BtnHangupPushed(evt));
            app.BtnHangup.Layout.Row = 15;  app.BtnHangup.Layout.Column = [1 2];
        end

        function dungTruc(app, cha, M)
        %DUNGTRUC Bốn hình bên phải, mỗi hình một trục và một dòng chú thích bên
        % dưới. Dạng sóng và bản đồ cùng cột, cùng lề trái, nên cùng một thời
        % điểm thẳng hàng dọc. Trục phóng to dùng chung thang biên độ với dạng
        % sóng nên bỏ số ở trục tung.
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
                'axMap', app.AxMap, 'axBars', app.AxBars, 'axPad', app.AxPad);
        end

        function coBanPhim(app, p)
        %COBANPHIM Trục bàn phím chiếm trọn panel P; bảng đã dựng (lần ve đầu
        % tiên) thì ui_pad đặt lại cỡ chữ theo kích thước mới.
            app.AxPad.Position = [0 0 p.InnerPosition(3:4)];
            if isstruct(app.V) && isfield(app.V, 'h') && isfield(app.V.h, 'ban')
                ui_pad(app.V.h.ban, 'co');
            end
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

function pos = viTriCuaSo()
%VITRICUASO Cửa sổ 1400×860, co lại cho vừa màn hình nhỏ - như DTMFApp.
scr = get(groot, 'ScreenSize');
w = min(1400, max(1100, scr(3) - 80));
h = min(860,  max(720,  scr(4) - 110));
pos = [max(1, round((scr(3) - w) / 2)), max(40, round((scr(4) - h) / 2)), w, h];
end

function ke(g, hang, cot, mau)
%KE Một đường kẻ lấp đầy ô (hang, cot): ô cao 1-2 px là kẻ ngang, ô rộng
% 1 px là kẻ dọc.
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
% [trái dưới phải trên], chú thích canh giữa dưới khung. Đặt tay vì cùng lý
% do như trucTrongO của DTMFApp: để trong grid thì MATLAB tự co khung vẽ theo
% bề rộng nhãn tick, hai trục chồng nhau lệch mép.
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
%CANHINH Khung vẽ của AX cách mép trong panel P đúng LE; chú thích nằm ở
% đáy panel, rộng bằng khung vẽ.
k = p.InnerPosition;
w = max(k(3) - le(1) - le(3), 1);
ax.InnerPosition = [le(1), le(2), w, max(k(4) - le(2) - le(4), 1)];
cap.Position = [le(1), 2, w, 22];
end

function s = dongHo(giay, coPhanMuoi)
%DONGHO 75.3 s -> '01:15' hoặc '01:15.3'.
giay = max(0, giay);
if coPhanMuoi
    s = sprintf('%02d:%04.1f', floor(giay / 60), mod(giay, 60));
else
    s = sprintf('%02d:%02d', floor(giay / 60), floor(mod(giay, 60)));
end
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
%CACH n dấu cách không ngắt (U+00A0). Nhãn HTML của uilabel gộp dấu cách
% thường và bỏ hẳn đoạn chỉ toàn khoảng trắng nằm giữa hai thẻ, nên khoảng
% cách phải nằm TRONG một span có chữ.
s = repmat(char(160), 1, n);
end

function s = htmlChu(s)
%HTMLCHU Thoát & < > để chữ thường (vd. thông báo lỗi) hiện đúng trong nhãn HTML.
s = strrep(strrep(strrep(s, '&', '&amp;'), '<', '&lt;'), '>', '&gt;');
end
