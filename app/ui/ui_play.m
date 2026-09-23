function daPhat = ui_play(y, fs)
%UI_PLAY Phát tín hiệu ra loa, trả về false chứ không ném lỗi khi máy im
% Cho người nghe đúng đoạn âm thanh mà bộ giải mã đang nhìn
%   DAPHAT = UI_PLAY(Y, FS) gửi Y ra loa ở tần số lấy mẫu FS và trả về true
%   nếu phát được. Tín hiệu rỗng, máy thiếu JVM hoặc máy không có thiết bị âm
%   thanh đều cho false - không trường hợp nào được ném lỗi.
%
%   Các bước hoạt động:
%       1. Y rỗng hoặc có phần tử không hữu hạn: không có gì để phát, trả về
%          false. sound() gặp NaN/Inf thì phát ra tiếng rè rất to.
%       2. ~usejava('jvm'): sound() dựng audioplayer bằng Java, gọi khi thiếu
%          JVM là lỗi cứng.
%       3. sound(y, fs) bọc try/catch. Máy ảo, phòng máy khóa thiết bị âm
%          thanh, hay card rời vừa rút đều ném lỗi ở đây; một buổi demo không
%          được sập chỉ vì cái loa.
%
%   Hàm này KHÔNG tự chặn chế độ chạy ẩn: quyết định "giao diện ẩn thì không
%   phát tiếng" nằm ở DTMFApp, vì chỉ nó biết mình đang chạy cho người xem hay
%   đang chạy trong matlab -batch.
%
%   Vì sao có giá trị trả về thay vì im lặng bỏ qua: DTMFApp ghi một dòng vào
%   TxtLog khi nhận false, nhờ vậy người dùng biết là máy im chứ không phải
%   nút hỏng.
%
%   Input:
%       y: 1×N double, tín hiệu cần phát, biên độ trong [-1, 1]; rỗng thì
%          không làm gì.
%       fs: 1×1 double, tần số lấy mẫu [Hz].
%
%   Output:
%       daPhat: 1×1 logical, true nếu sound() chạy trót lọt.
%
%   Example:
%       ui_play(dtmf_generate('5'), 8000)   % true nếu máy có loa

daPhat = false;

% Bước 1.
if isempty(y) || ~all(isfinite(y(:)))
    return
end

% Bước 2.
if ~usejava('jvm')
    return
end

% Bước 3.
try
    sound(y, fs);
    daPhat = true;
catch
    % Nuốt lỗi là CỐ Ý và chỉ ở đây: người gọi đọc daPhat để biết chuyện gì
    % đã xảy ra, còn giao diện thì vẫn chạy tiếp.
end

end
