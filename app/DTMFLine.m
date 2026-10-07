classdef DTMFLine < handle
%DTMFLINE Đầu MATLAB của đường dây điện thoại: nối tới cầu nối của trang web, nhận âm thanh và gửi phím
% Thay cho cái micro khi trang web và MATLAB chạy trên cùng một máy: âm thanh đi thẳng theo dây, không qua không khí
%   LINE = DTMFLINE() tạo đầu đường dây, CHƯA nối. LINE = DTMFLINE(PORT) dùng
%   cổng khác mặc định 8765.
%   [OK, LOI] = LINE.noi() nối tới cầu nối ở 127.0.0.1:PORT.
%   TIN = LINE.doc() lấy mọi byte đang chờ, tách thành các tin.
%   LINE.gui(S) gửi struct S thành một dòng JSON.
%   LINE.conSong() cho biết đường dây còn sống. LINE.ngat() cắt đường dây.
%
%   Đường đi của âm thanh:
%       trang web --WebSocket--> cầu nối (web/server/line.ts, chạy trong
%       npm run dev) --TCP, mỗi dòng một JSON--> DTMFLine --> dtmf_listen
%   Trình duyệt không mở được cổng TCP, còn tcpserver của MATLAB thuộc
%   Instrument Control Toolbox; tcpclient thì có sẵn trong MATLAB gốc. Vì vậy
%   cầu nối Node đứng làm máy chủ và MATLAB là bên nối vào. Giao thức đầy đủ
%   nằm ở web/src/line/protocol.ts.
%
%   Các bước hoạt động:
%       1. noi: dựng tcpclient. Cổng chưa mở thì Windows thử lại kết nối,
%          mất khoảng 3,4 s dù ConnectTimeout nhỏ hơn (đo 06/10/2026) - người
%          gọi không nên thử lại liên tục trong vòng lặp giao diện.
%       2. doc: đọc hết byte có sẵn, nối với phần dòng dở lần trước, tách theo
%          '\n', jsondecode từng dòng. Tin âm thanh {"t":"pcm","d":base64}
%          giải base64 thành int16 rồi chia 32767; các tin pcm liền nhau gộp
%          thành MỘT tin để bộ giải mã luồng chỉ chạy một lần cho mỗi lượt đọc.
%       3. conSong: tcpclient KHÔNG báo khi đầu kia đóng (ghi vẫn thành công,
%          đọc chỉ hết thời gian chờ). Cầu nối gửi {"t":"ping"} mỗi giây, nên
%          quá HET_HAN giây không nhận được byte nào nghĩa là dây đã đứt.
%
%   Lớp này KHÔNG xử lý tín hiệu: nó chỉ đổi byte thành mẫu, như audiorecorder
%   của ui_mic. Giải mã vẫn là việc của dtmf_listen.
%
%   Example:
%       line = DTMFLine();
%       if line.noi()
%           line.gui(struct('t', 'hello', 'method', 'Goertzel'));
%           tin = line.doc();      % cell các struct, vd. tin{1}.t = 'call'
%       end

    properties (Constant)
        % Không có byte nào trong chừng này giây thì coi như đứt dây [s]. Cầu
        % nối gửi ping mỗi 1 s, nên 3,5 s là lỡ ba nhịp liền.
        HET_HAN = 3.5
    end

    properties (SetAccess = private)
        Host    char = '127.0.0.1'
        Port    double = 8765
        % true từ lúc noi thành công tới lúc ngat hoặc phát hiện đứt dây.
        DaNoi   logical = false
        % 50 tin gửi gần nhất, mới nhất ở cuối - để xem lại và để test đọc,
        % vì test chạy ẩn không có cầu nối thật.
        DaGui   cell = {}
    end

    properties (Access = private)
        C                       % tcpclient
        Du      uint8 = zeros(1, 0, 'uint8')    % phần dòng chưa trọn
        MocNhan                 % tic của lần cuối nhận được byte
    end

    methods

        function obj = DTMFLine(port)
            if nargin >= 1
                obj.Port = port;
            end
        end

        function delete(obj)
            ngat(obj);
        end

        function [ok, loi] = noi(obj)
        %NOI Nối tới cầu nối. Không ném lỗi: thất bại thì ok = false kèm lý do.
            ngat(obj);
            loi = blanks(0);
            try
                obj.C = tcpclient(obj.Host, obj.Port, 'ConnectTimeout', 1.5, 'Timeout', 1);
                obj.DaNoi   = true;
                obj.MocNhan = tic;
                obj.Du      = zeros(1, 0, 'uint8');
            catch ME
                obj.C = [];
                obj.DaNoi = false;
                loi = sprintf(['Không thấy cầu nối ở %s:%d - chạy npm run dev trong ' ...
                    'thư mục web/ rồi nối lại. (%s)'], obj.Host, obj.Port, ME.message);
            end
            ok = obj.DaNoi;
        end

        function ngat(obj)
        %NGAT Cắt đường dây; xóa tcpclient là đóng socket.
            obj.C = [];
            obj.DaNoi = false;
            obj.Du = zeros(1, 0, 'uint8');
        end

        function s = conSong(obj)
        %CONSONG Đã nối và vẫn nhận được byte trong HET_HAN giây gần nhất.
            s = obj.DaNoi && ~isempty(obj.MocNhan) && toc(obj.MocNhan) < obj.HET_HAN;
        end

        function tin = doc(obj)
        %DOC Đọc mọi byte đang chờ và tách thành tin. Chưa nối thì trả {}.
            tin = {};
            if ~obj.DaNoi || isempty(obj.C)
                return
            end
            try
                n = obj.C.NumBytesAvailable;
                if n == 0
                    return
                end
                moi = read(obj.C, n, 'uint8');
            catch
                % Socket hỏng hẳn (máy chủ bị giết): coi như đứt dây.
                ngat(obj);
                return
            end
            obj.MocNhan = tic;
            [tin, obj.Du] = DTMFLine.tachTin(obj.Du, moi);
        end

        function gui(obj, s)
        %GUI Gửi một struct thành một dòng JSON UTF-8 (tên phương pháp có dấu).
            obj.DaGui{end+1} = s;
            if numel(obj.DaGui) > 50
                obj.DaGui = obj.DaGui(end-49:end);
            end
            if ~obj.DaNoi || isempty(obj.C)
                return
            end
            try
                write(obj.C, [unicode2native(jsonencode(s), 'UTF-8'), uint8(10)]);
            catch
                ngat(obj);
            end
        end

    end

    methods (Static)

        function [tin, du] = tachTin(du, moi)
        %TACHTIN Nối byte mới vào phần dòng dở, tách các dòng trọn thành tin.
        % Tách riêng thành hàm tĩnh để test được mà không cần cầu nối thật.
        %   du, moi: uint8 hàng. tin: cell 1×k struct, theo đúng thứ tự đến;
        %   tin pcm có trường .x (double hàng, [-1, 1]) thay cho .d. Dòng hỏng
        %   bị bỏ qua, không làm hỏng các dòng sau.
            b = [reshape(uint8(du), 1, []), reshape(uint8(moi), 1, [])];
            xuong = find(b == 10);
            tin = {};
            if isempty(xuong)
                du = b;
                return
            end
            du = b(xuong(end)+1:end);

            % Mỗi dòng nhiều nhất một tin: cấp sẵn rồi cắt phần thừa ở cuối.
            tin = cell(1, numel(xuong));
            nTin = 0;
            dau = 1;
            for k = xuong
                dong = b(dau:k-1);
                dau = k + 1;
                if isempty(dong)
                    continue
                end
                try
                    s = jsondecode(native2unicode(dong, 'UTF-8'));
                catch
                    continue
                end
                if ~isstruct(s) || ~isfield(s, 't')
                    continue
                end
                s.t = char(s.t);

                if strcmp(s.t, 'pcm')
                    x = DTMFLine.giaiPcm(s);
                    % Gộp vào tin pcm đứng ngay trước nếu có.
                    if nTin > 0 && strcmp(tin{nTin}.t, 'pcm')
                        tin{nTin}.x = [tin{nTin}.x, x];
                        continue
                    end
                    s = struct('t', 'pcm', 'x', x);
                end
                nTin = nTin + 1;
                tin{nTin} = s;
            end
            tin = tin(1:nTin);
        end

    end

    methods (Static, Access = private)

        function x = giaiPcm(s)
        %GIAIPCM base64 -> int16 little-endian -> double trong [-1, 1].
        % Byte lẻ ở cuối (không đủ một mẫu) bị bỏ. Máy x86/ARM đều little-endian
        % như trình duyệt, nên typecast không cần đảo byte.
            x = zeros(1, 0);
            if ~isfield(s, 'd') || isempty(s.d)
                return
            end
            b = matlab.net.base64decode(char(s.d));
            b = reshape(b(1:2*floor(numel(b)/2)), 1, []);
            if isempty(b)
                return
            end
            x = double(typecast(b, 'int16')) / 32767;
        end

    end

end
