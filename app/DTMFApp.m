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
%       4. Hai nguồn tín hiệu, chọn ở thẻ 01; thẻ 02 chỉ hiện nút của nguồn
%          đang chọn, và capNhatNut tô màu nhấn cho nút của bước cần bấm tiếp.
%          Tổng hợp: ① Phát tín hiệu -> ② Giải mã. Micro: "Giải mã trực tiếp"
%          đưa từng đoạn micro qua dtmf_listen và hiện phím ngay khi nhận
%          ra; "Ghi âm rồi giải mã" thu tới khi bấm lần nữa rồi giải mã cả
%          bản ghi bằng dtmf_run. Chạy ẩn thì không mở micro - test đưa mẫu
%          vào qua nhanMauMic và napBanGhi.
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

        % Nguồn tín hiệu: hai nút dạng tab. PnlKeypad và PnlMic là thẻ 02 của
        % hai nguồn, chồng lên nhau ở cùng một ô lưới - chỉ một cái hiện.
        BtnSrcGen   matlab.ui.control.Button
        BtnSrcMic   matlab.ui.control.Button
        PnlKeypad   matlab.ui.container.Panel
        PnlMic      matlab.ui.container.Panel

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
        BtnRecord   matlab.ui.control.Button
        BtnListen   matlab.ui.control.Button

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

        % Micro. CheDoMic: '' (tắt) | 'ghi' (ghi âm rồi giải mã) | 'nghe' (giải
        % mã trực tiếp). Mic là audiorecorder, rỗng khi tắt hoặc khi chạy ẩn.
        Mic
        CheDoMic    char = ''
        DaDoc       double = 0      % số mẫu đã lấy khỏi Mic từ lúc record()
        MocVe                       % tic của lần vẽ gần nhất trong chế độ micro

        % S.y hiện tại đến từ micro chứ không phải dtmf_generate: không có x
        % để cộng lại nhiễu, không có chuỗi đã phát để so.
        NguonMic    logical = false

        % Trạng thái bộ giải mã luồng - xem app/dtmf_listen.m. TuLuong: kết quả
        % đang hiện là của L (nghe trực tiếp), chứ không phải của dtmf_run.
        % Cần vì S.keysHat khi đó chỉ giữ 12 phím cuối, còn dòng trạng thái
        % phải báo tổng số phím đã nghe được.
        L           struct
        TuLuong     logical = false
    end

    properties (Constant, Access = private)
        % Chu kỳ tick của micro [s]: 50 ms = 400 mẫu, gần hai khung Goertzel.
        CHU_KY_MIC = 0.05
        % Chu kỳ vẽ lại ba trục khi nghe trực tiếp [s]. Một lần ui_refresh tốn
        % ~0.4 s (đo 29/09/2026, giao diện hiện), vẽ theo từng tick thì giao
        % diện đứng hình; phím mới vẫn hiện ngay vì chỉ đổi một nhãn (~20 ms).
        CHU_KY_VE  = 1.0
        % Ghi âm tự dừng sau chừng này giây [s].
        GHI_TOI_DA = 20
        % Nghe quá chừng này giây thì ghi lại từ đầu [s], vì getaudiodata trả
        % CẢ bản ghi nên mỗi tick chậm dần theo độ dài bản ghi.
        NGHE_TOI_DA = 120
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
        %DELETE Tắt micro rồi đóng cửa sổ khi đối tượng bị hủy.
        % Tắt micro TRƯỚC: tick của nó còn chạy sau khi app bị hủy thì mỗi
        % 50 ms lại ném một lỗi ra cửa sổ lệnh.
            tatMic(app);
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end

        % ------------------------------------------------------------ callback
        %
        % Cả mười hai callback dưới đây để PUBLIC, khác App Designer (mặc
        % định private), vì unit test gọi thẳng chúng: không có API công khai
        % nào để "bấm" một uibutton bằng code.

        function BtnSrcPushed(app, event)
        %BTNSRCPUSHED Callback dùng chung cho hai nút nguồn: tổng hợp / micro.
        % Bấm lại nút nguồn đang chọn thì không làm gì - không xóa kết quả.
            mic = event.Source == app.BtnSrcMic;
            if mic ~= app.NguonMic && isempty(app.CheDoMic)
                doiNguon(app, mic);
            end
        end

        function Btn1Pushed(app, event)
        %BTN1PUSHED Callback dùng chung cho cả 12 nút bàn phím.
            app.EfKeys.Value = [app.EfKeys.Value, event.Source.Text];
            capNhatNut(app);
            phatPhim(app, event.Source.Text);
        end

        function EfKeysValueChanging(app, event)
        %EFKEYSVALUECHANGING Gõ phím thì tô lại nút: chuỗi đã khác lần phát
        % trước nghĩa là bước tiếp theo lại là ① Phát tín hiệu.
            capNhatNut(app, event.Value);
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
        % Đang dùng micro thì không có tín hiệu cố định để giải mã lại - xem
        % doiPhuongPhapMic. Chưa có tín hiệu thì chỉ ghi nhận lựa chọn: giải
        % mã một tín hiệu rỗng sẽ đánh dấu "đã giải mã" và làm tắt màu nhấn
        % của bước tiếp theo.
            if ~isempty(app.CheDoMic)
                doiPhuongPhapMic(app);
            elseif ~isempty(app.S.y)
                BtnDecodePushed(app, []);
            else
                docUI(app);
                capNhatKetQua(app);
            end
        end

        function BtnClearPushed(app, ~)
        %BTNCLEARPUSHED Xóa trắng ô chuỗi phím, không đụng tín hiệu đang có.
            app.EfKeys.Value = '';
            capNhatNut(app);
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

            % Âm thanh micro không có tín hiệu sạch x để cộng lại nhiễu; đi
            % tiếp thì congNhieu thay bản ghi bằng một tín hiệu rỗng.
            if app.NguonMic
                capNhatKetQua(app);
                return
            end

            if congNhieu(app)
                giaiMa(app);
            end
            veLai(app);
        end

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
        % Có phím mới thì chỉ đổi thẻ Kết quả (~20 ms) để phím hiện ngay; ba
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
        %NAPBANGHI Lấy một đoạn âm thanh thu từ micro làm tín hiệu hiện tại rồi giải mã.
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

            app.NguonMic = false;

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
            app.TuLuong  = false;
        end

        function veLai(app)
        %VELAI Vẽ lại ba trục qua ui_refresh, rồi cập nhật thẻ Kết quả.
        % Thẻ Kết quả nằm NGOÀI ui_refresh vì hợp đồng của hàm đó chỉ gồm sáu
        % thành phần (CONTRACTS §8) - test_ui_smoke dựng app giả đúng sáu thứ.
            ui_refresh(app);
            capNhatKetQua(app);
            capNhatNut(app);
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
            elseif app.NguonMic
                app.LblSent.Text = '(micro)';
                [txt, mau] = trangThaiMic(app, tenPP, M);
            elseif isempty(S.y)
                % Chấm rỗng kèm việc cần làm tiếp - cùng ý với màu nhấn trên
                % nút của capNhatNut, nói bằng chữ cho ai chưa để ý màu.
                txt = '○  Chưa có tín hiệu   ·   gõ phím rồi bấm ①';
                mau = M.chuMo;
            elseif ~app.DaGiaiMa
                txt = sprintf('○  Đã phát %d phím   ·   bấm ② để giải mã', numel(daPhat));
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
                        txt = '○  Chưa có tín hiệu   ·   chọn một cách thu ở thẻ 02';
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
        %DUNGGHI Dừng ghi, lấy cả bản ghi làm tín hiệu rồi giải mã.
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
        % veTruc = true vẽ lại cả ba trục qua ui_refresh; false chỉ đổi thẻ
        % Kết quả. Nhãn "Đọc được" chỉ vừa khoảng 12 ký tự ở cỡ chữ 24, nên
        % chỉ hiện 12 phím cuối; số phím đầy đủ nằm ở dòng trạng thái.
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

        function capNhatNut(app, dangGo)
        %CAPNHATNUT Hiện thẻ của nguồn đang chọn, tô nút của bước cần làm tiếp
        % theo, khóa nút chưa dùng được.
        % Mục đích: nhìn vào là biết bấm gì. Luật cho nguồn tổng hợp:
        %   - chưa có tín hiệu, hoặc chuỗi phím đã sửa sau lần phát  -> ①
        %   - đã phát, chưa giải mã                                   -> ②
        %   - đã giải mã                                              -> không nút nào
        % "② Giải mã" và "▶ Nghe" bị khóa khi chưa có gì để giải mã hay để nghe;
        % "① Phát tín hiệu" bị khóa khi ô chuỗi phím trống.
        % dangGo: chữ trong ô chuỗi phím. Lúc đang gõ, EfKeys.Value CHƯA đổi
        % (ValueChanging tới trước), nên EfKeysValueChanging truyền event.Value.
            if nargin < 2
                dangGo = app.EfKeys.Value;
            end
            dangGo = reshape(char(dangGo), 1, []);

            M = ui_theme();
            S = app.S;
            ranh = isempty(app.CheDoMic);
            ghi  = strcmp(app.CheDoMic, 'ghi');
            nghe = strcmp(app.CheDoMic, 'nghe');

            % Nguồn. Đang dùng micro thì không cho đổi nguồn: đổi là xóa kết
            % quả, mà micro vẫn đang đổ mẫu vào.
            kieuTab(app.BtnSrcGen, ~app.NguonMic, M);
            kieuTab(app.BtnSrcMic, app.NguonMic, M);
            app.BtnSrcGen.Enable = matlab.lang.OnOffSwitchState(ranh);
            app.BtnSrcMic.Enable = matlab.lang.OnOffSwitchState(ranh);
            app.PnlKeypad.Visible = matlab.lang.OnOffSwitchState(~app.NguonMic);
            app.PnlMic.Visible    = matlab.lang.OnOffSwitchState(app.NguonMic);

            % Tổng hợp.
            daPhat = [];
            if isstruct(S.meta) && isfield(S.meta, 'keys')
                daPhat = S.meta.keys;
            end
            coTin  = ~app.NguonMic && ~isempty(S.y);
            khopGo = coTin && isequal(dangGo, daPhat);
            kieuNut(app.BtnGen,    ~isempty(dangGo) && ~khopGo, M);
            kieuNut(app.BtnDecode, khopGo && ~app.DaGiaiMa, M);
            app.BtnGen.Enable    = matlab.lang.OnOffSwitchState(~isempty(dangGo));
            app.BtnDecode.Enable = matlab.lang.OnOffSwitchState(coTin);

            % Nghe lại: có tín hiệu (tổng hợp hay bản ghi) và micro đang nghỉ.
            app.BtnPlay.Enable = matlab.lang.OnOffSwitchState(ranh && ~isempty(S.y));

            % Micro. Nút đang chạy đổi sang màu nhấn: nhìn là biết micro đang
            % mở; nút micro còn lại bị khóa.
            app.BtnRecord.Enable = matlab.lang.OnOffSwitchState(ranh || ghi);
            app.BtnListen.Enable = matlab.lang.OnOffSwitchState(ranh || nghe);
            kieuNutMic(app.BtnListen, nghe, '◉  Giải mã trực tiếp', '■  Dừng giải mã trực tiếp', M);
            kieuNutMic(app.BtnRecord, ghi, '●  Ghi âm rồi giải mã', '■  Dừng ghi và giải mã', M);
        end

        function doiNguon(app, mic)
        %DOINGUON Chuyển sang nguồn khác và xóa kết quả của nguồn cũ.
        % Xóa vì để lại thì thẻ Kết quả và ba trục vẫn nói về một tín hiệu
        % không còn liên quan gì tới thẻ 02 đang hiện. Ô chuỗi phím giữ nguyên:
        % quay lại nguồn tổng hợp là bấm ① được ngay.
            app.NguonMic = mic;
            xoaKetQua(app);
            app.S.lastError = blanks(0);
            app.S.x    = zeros(1, 0);
            app.S.y    = zeros(1, 0);
            app.S.meta = [];
            app.TuLuong = false;
            veLai(app);
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
        %DUNGCOTTRAI Ba thẻ đánh số theo thứ tự thao tác, nhật ký lỗi nhỏ ở đáy.
        % 01 chọn nguồn và bộ giải mã. 02 là thẻ của ĐÚNG nguồn đang chọn -
        % hai thẻ chồng lên nhau ở cùng một ô lưới, capNhatNut ẩn thẻ kia -
        % nên lúc nào trên màn hình cũng chỉ có nút của một quy trình. 03 là
        % kết quả, kèm nút nghe lại chính tín hiệu vừa phát hay vừa ghi.
            gl = uigridlayout(cha, [4 1]);
            gl.RowHeight       = {118, 338, 130, '1x'};
            gl.ColumnWidth     = {'1x'};
            gl.Padding         = [0 0 0 0];
            gl.RowSpacing      = 12;
            gl.BackgroundColor = M.nen;
            gl.Layout.Row      = 2;
            gl.Layout.Column   = 1;

            dungTheThietLap(app, gl, M);
            dungTheTongHop(app, gl, M);
            dungTheMic(app, gl, M);
            dungTheKetQua(app, gl, M);

            % --- nhật ký: chỉ ghi lỗi, nên để nhỏ, không đánh số, nằm cuối
            [pn, gc] = theCard(gl, '', 'Nhật ký lỗi', M);
            pn.Layout.Row = 4;

            app.TxtLog = uitextarea(gc, 'Editable', 'off', ...
                'FontName', M.fontMono, 'FontSize', 10, 'FontColor', M.sai, ...
                'BackgroundColor', M.the, ...
                'Placeholder', 'Chưa có lỗi nào');
            app.TxtLog.Layout.Row = 2;

            capNhatNut(app);
        end

        function dungTheThietLap(app, gl, M)
        %DUNGTHETHIETLAP Thẻ 01: nguồn tín hiệu (hai nút dạng tab) và bộ giải mã.
        % Bộ giải mã nằm ở đây chứ không trong thẻ 02 vì nó dùng chung cho cả
        % hai nguồn.
            [p, gc] = theCard(gl, '01', 'Thiết lập', M);
            p.Layout.Row = 1;

            gt = uigridlayout(gc, [2 2]);
            gt.RowHeight       = {30, 30};
            gt.ColumnWidth     = {72, '1x'};
            gt.Padding         = [0 0 0 0];
            gt.RowSpacing      = 8;
            gt.ColumnSpacing   = 8;
            gt.BackgroundColor = M.the;
            gt.Layout.Row      = 2;

            nhanTinh(gt, 1, 'Nguồn', M);
            gs = uigridlayout(gt, [1 2]);
            gs.ColumnWidth     = {'1x', '1x'};
            gs.Padding         = [0 0 0 0];
            gs.ColumnSpacing   = 4;
            gs.BackgroundColor = M.the;
            gs.Layout.Row = 1;  gs.Layout.Column = 2;

            app.BtnSrcGen = uibutton(gs, 'Text', 'Tổng hợp', 'FontSize', 12, ...
                'Tooltip', 'Gõ chuỗi phím, máy tự sinh tín hiệu DTMF có nhiễu rồi giải mã', ...
                'ButtonPushedFcn', @(src, evt) app.BtnSrcPushed(evt));
            app.BtnSrcMic = uibutton(gs, 'Text', 'Micro', 'FontSize', 12, ...
                'Tooltip', 'Giải mã âm DTMF thu từ micro, vd. bấm số trên điện thoại', ...
                'ButtonPushedFcn', @(src, evt) app.BtnSrcPushed(evt));

            nhanTinh(gt, 2, 'Bộ giải mã', M);
            app.DdMethod = uidropdown(gt, ...
                'Items',     {'FFT', 'Goertzel', 'Ngân hàng bộ lọc'}, ...
                'ItemsData', {'fft', 'goertzel', 'filterbank'}, ...
                'Value',     app.S.method, ...
                'FontColor', M.muc, 'BackgroundColor', M.the, ...
                'Tooltip', 'Đổi bộ giải mã thì giải mã lại ngay', ...
                'ValueChangedFcn', @(src, evt) app.DdMethodValueChanged(evt));
            app.DdMethod.Layout.Row = 2;  app.DdMethod.Layout.Column = 2;
        end

        function dungTheTongHop(app, gl, M)
        %DUNGTHETONGHOP Thẻ 02 của nguồn tổng hợp: chuỗi phím, bàn phím, SNR,
        % rồi hai nút đánh số theo đúng thứ tự bấm.
        % Ô chuỗi phím nằm NGAY TRÊN bàn phím: bấm phím nào thấy ký tự hiện
        % ra ở đó, không phải liếc sang thẻ khác. SNR nằm dưới bàn phím và
        % trên nút ①, vì nó là tham số của bước phát chứ không phải bước giải.
            [app.PnlKeypad, gc] = theCard(gl, '02', 'Tín hiệu tổng hợp', M);
            app.PnlKeypad.Layout.Row = 2;

            gs = uigridlayout(gc, [3 1]);
            gs.RowHeight       = {'1x', 42, 36};
            gs.ColumnWidth     = {'1x'};
            gs.Padding         = [0 0 0 0];
            gs.RowSpacing      = 10;
            gs.BackgroundColor = M.the;
            gs.Layout.Row      = 2;

            kg = uigridlayout(gs, [6 4]);
            kg.RowHeight       = [{30, 14}, repmat({'1x'}, 1, 4)];
            kg.ColumnWidth     = [{30}, repmat({'1x'}, 1, 3)];
            kg.Padding         = [0 0 0 0];
            kg.RowSpacing      = 6;
            kg.ColumnSpacing   = 6;
            kg.BackgroundColor = M.the;
            kg.Layout.Row      = 1;

            app.EfKeys = uieditfield(kg, 'text', ...
                'FontName', M.fontMono, 'FontSize', 15, 'FontColor', M.muc, ...
                'Placeholder', 'vd. 0912345', ...
                'ValueChangingFcn', @(src, evt) app.EfKeysValueChanging(evt));
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

            % SNR thẳng cột với cột nhãn tần số của bàn phím. Thanh trượt nằm
            % ở mép trên hàng, vạch chia bên dưới: nhãn hai bên cũng canh trên
            % để ba thứ thẳng một đường.
            gt = uigridlayout(gs, [1 3]);
            gt.ColumnWidth     = {30, '1x', 44};
            gt.Padding         = [0 0 0 0];
            gt.ColumnSpacing   = 6;
            gt.BackgroundColor = M.the;
            gt.Layout.Row      = 2;

            l = nhanTinh(gt, 1, 'SNR', M);
            l.VerticalAlignment = 'top';
            app.SldSNR = uislider(gt, ...
                'Limits',          [-5 30], ...
                'Value',           app.S.snrDb, ...
                'MajorTicks',      -5:5:30, ...
                'MinorTicks',      [], ...
                'FontSize',        9, ...
                'FontColor',       M.chuMo, ...
                'Tooltip', 'Mức nhiễu của tín hiệu phát; thả chuột thì cộng lại nhiễu và giải mã lại', ...
                'ValueChangingFcn', @(src, evt) app.SldSNRValueChanging(evt), ...
                'ValueChangedFcn',  @(src, evt) app.SldSNRValueChanged(evt));
            app.SldSNR.Layout.Row = 1;  app.SldSNR.Layout.Column = 2;

            app.LblSNR = uilabel(gt, 'Text', blanks(0), ...
                'FontSize', 12, 'FontWeight', 'bold', 'FontColor', M.nhan, ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
            app.LblSNR.Layout.Row = 1;  app.LblSNR.Layout.Column = 3;
            hienSNR(app, app.S.snrDb);

            % Hai bước, đánh số đúng thứ tự bấm. Màu do capNhatNut đặt: nút
            % của bước cần làm TIẾP THEO tô màu nhấn, nút kia nền trắng.
            gb = uigridlayout(gs, [1 2]);
            gb.ColumnWidth     = {'1x', '1x'};
            gb.Padding         = [0 0 0 0];
            gb.ColumnSpacing   = 8;
            gb.BackgroundColor = M.the;
            gb.Layout.Row      = 3;

            app.BtnGen = uibutton(gb, 'Text', '①  Phát tín hiệu', 'FontSize', 12, ...
                'Tooltip', 'Sinh tín hiệu DTMF từ chuỗi phím rồi cộng nhiễu theo SNR', ...
                'ButtonPushedFcn', @(src, evt) app.BtnGenPushed(evt));
            app.BtnDecode = uibutton(gb, 'Text', '②  Giải mã', 'FontSize', 12, ...
                'Tooltip', 'Giải mã tín hiệu vừa phát bằng bộ giải mã đang chọn', ...
                'ButtonPushedFcn', @(src, evt) app.BtnDecodePushed(evt));
        end

        function dungTheMic(app, gl, M)
        %DUNGTHEMIC Thẻ 02 của nguồn micro: một dòng hướng dẫn, hai nút, mỗi
        % nút một câu nói rõ khi nào dùng nó.
        % Nghe trực tiếp đặt TRƯỚC vì đó là cách trình diễn chính; ghi âm là
        % cách dự phòng khi cần xem đủ ba đồ thị của cả bản ghi.
            [app.PnlMic, gc] = theCard(gl, '02', 'Thu từ micro', M);
            app.PnlMic.Layout.Row = 2;

            gm = uigridlayout(gc, [6 1]);
            gm.RowHeight       = {34, 40, 30, 40, 30, '1x'};
            gm.ColumnWidth     = {'1x'};
            gm.Padding         = [0 0 0 0];
            gm.RowSpacing      = 6;
            gm.BackgroundColor = M.the;
            gm.Layout.Row      = 2;

            l = uilabel(gm, 'WordWrap', 'on', 'FontSize', 11, 'FontColor', M.chuPhu, ...
                'Text', 'Đặt điện thoại cách micro 5–10 cm, bật âm bàn phím, rồi chọn một cách thu:');
            l.Layout.Row = 1;

            app.BtnListen = uibutton(gm, 'FontSize', 12, ...
                'Tooltip', 'Nghe micro liên tục, hiện phím ngay khi nhận ra; bấm lần nữa để dừng', ...
                'ButtonPushedFcn', @(src, evt) app.BtnListenPushed(evt));
            app.BtnListen.Layout.Row = 2;
            chuThich(gm, 3, 'Phím hiện ra ngay khi bấm. Dùng để trình diễn trực tiếp.', M);

            app.BtnRecord = uibutton(gm, 'FontSize', 12, ...
                'Tooltip', sprintf(['Ghi âm từ micro (tối đa %d s); bấm lần nữa để ' ...
                    'dừng và giải mã bằng bộ giải mã đang chọn'], app.GHI_TOI_DA), ...
                'ButtonPushedFcn', @(src, evt) app.BtnRecordPushed(evt));
            app.BtnRecord.Layout.Row = 4;
            chuThich(gm, 5, sprintf(['Thu tối đa %d s, dừng thì giải mã cả bản ghi ' ...
                'và vẽ đủ ba đồ thị. Dùng khi cần phân tích.'], app.GHI_TOI_DA), M);

            l = chuThich(gm, 6, ['Đọc được 0 phím? Dòng trạng thái ở thẻ Kết quả ghi lý do: ' ...
                'twist - hai âm lệch biên độ (loa yếu tần số thấp), level - âm quá nhỏ ' ...
                'hoặc lẫn tạp âm.'], M);
            l.VerticalAlignment = 'bottom';
        end

        function dungTheKetQua(app, gl, M)
        %DUNGTHEKETQUA Thẻ 03: chuỗi đã phát ngay trên chuỗi đọc được, cùng phông
        % đơn cách để mắt so được từng cột ký tự.
        % Nút "Nghe" đứng cạnh "Đã phát": nó phát lại đúng tín hiệu đang xét -
        % tín hiệu tổng hợp ĐÃ cộng nhiễu, hoặc bản ghi micro. Màu chữ
        % LblDecoded (đúng xanh / sai đỏ) do ui_refresh đặt; LblSent và
        % LblStatus do capNhatKetQua đặt.
            [pk, gc] = theCard(gl, '03', 'Kết quả', M);
            pk.Layout.Row = 3;

            gk = uigridlayout(gc, [3 3]);
            gk.RowHeight       = {24, 34, 18};
            gk.ColumnWidth     = {72, '1x', 74};
            gk.Padding         = [0 0 0 0];
            gk.RowSpacing      = 2;
            gk.ColumnSpacing   = 8;
            gk.BackgroundColor = M.the;
            gk.Layout.Row      = 2;

            nhanTinh(gk, 1, 'Đã phát', M);
            app.LblSent = uilabel(gk, 'Text', blanks(0), ...
                'FontName', M.fontMono, 'FontSize', 15, 'FontColor', M.chuPhu);
            app.LblSent.Layout.Row = 1;  app.LblSent.Layout.Column = 2;

            app.BtnPlay = uibutton(gk, 'Text', '▶  Nghe', 'FontSize', 11, ...
                'FontColor', M.muc, 'BackgroundColor', M.the, ...
                'Tooltip', 'Phát ra loa đúng tín hiệu bộ giải mã đang xét (đã cộng nhiễu, hoặc bản ghi micro)', ...
                'ButtonPushedFcn', @(src, evt) app.BtnPlayPushed(evt));
            app.BtnPlay.Layout.Row = 1;  app.BtnPlay.Layout.Column = 3;

            nhanTinh(gk, 2, 'Đọc được', M);
            app.LblDecoded = uilabel(gk, 'Text', blanks(0), ...
                'FontName', M.fontMono, 'FontSize', 24, 'FontWeight', 'bold', ...
                'FontColor', M.muc);
            app.LblDecoded.Layout.Row = 2;  app.LblDecoded.Layout.Column = [2 3];

            app.LblStatus = uilabel(gk, 'Text', blanks(0), ...
                'FontSize', 11, 'FontColor', M.chuMo);
            app.LblStatus.Layout.Row = 3;  app.LblStatus.Layout.Column = [1 3];
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

function kieuNut(nut, buocTiep, M)
%KIEUNUT Nút của bước cần bấm tiếp theo: nền màu nhấn, chữ trắng đậm. Nút
% khác: nền trắng, chữ thường. MỘT màu nhấn cho thứ đang cần chú ý - ui_theme.
% FontWeight là dấu hiệu test đọc được, không phải chỉ để trang trí.
if buocTiep
    set(nut, 'FontWeight', 'bold', 'FontColor', [1 1 1], 'BackgroundColor', M.nhan);
else
    set(nut, 'FontWeight', 'normal', 'FontColor', M.muc, 'BackgroundColor', M.the);
end
end

function kieuNutMic(nut, dangChay, chuNghi, chuChay, M)
%KIEUNUTMIC Nút micro lúc nghỉ: nền trắng; lúc chạy: nền màu nhấn, chữ "Dừng".
if dangChay
    set(nut, 'Text', chuChay);
else
    set(nut, 'Text', chuNghi);
end
kieuNut(nut, dangChay, M);
end

function kieuTab(nut, dangChon, M)
%KIEUTAB Nút nguồn đang chọn: nền nhạt màu nhấn, chữ màu nhấn đậm - khác hẳn
% nút hành động (nền đặc) để không ai tưởng bấm vào là "chạy" thứ gì.
if dangChon
    set(nut, 'FontWeight', 'bold', 'FontColor', M.nhan, 'BackgroundColor', M.nhanNhat);
else
    set(nut, 'FontWeight', 'normal', 'FontColor', M.chuPhu, 'BackgroundColor', M.the);
end
end

function l = chuThich(cha, hang, txt, M)
%CHUTHICH Một câu chú thích nhỏ, tự xuống dòng, dưới một nút của thẻ micro.
l = uilabel(cha, 'Text', txt, 'WordWrap', 'on', 'FontSize', 10, ...
    'FontColor', M.chuMo, 'VerticalAlignment', 'top');
l.Layout.Row = hang;
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
