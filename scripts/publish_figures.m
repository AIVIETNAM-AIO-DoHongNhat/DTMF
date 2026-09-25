%% publish_figures.m
% PUBLISH_FIGURES Chép hình từ results/figures/ sang report/template/Figures/
%
% MỘT CHIỀU, không bao giờ ngược lại. results/figures/ là nơi máy sinh ra;
% report/template/Figures/ là nơi LaTeX đọc vào. Sửa tay một file bên đích sẽ
% bị lần chạy sau ghi đè mà không một lời cảnh báo - muốn đổi hình thì sửa
% scripts/make_figures.m rồi chạy lại cả hai script.
%
% Vì sao cần hai thư mục thay vì cho LaTeX đọc thẳng results/figures/:
% results/ nằm trong .gitignore (sinh lại được, mỗi lần sinh là một blob nhị
% phân mới), còn report/template/Figures/ thì PHẢI nằm trong git - người chấm
% và bạn cùng nhóm cần dịch được báo cáo mà không phải cài MATLAB.
%
% Cách dùng:  cd <repo>; addpath('scripts'); run_bench; make_figures; publish_figures

clear;
root = fileparts(fileparts(mfilename('fullpath')));

srcDir = fullfile(root, 'results', 'figures');
dstDir = fullfile(root, 'report', 'template', 'Figures');

if ~isfolder(srcDir)
    error('publish_figures:noSource', ...
        'Khong thay %s. Chay make_figures truoc.', srcDir);
end
if ~isfolder(dstDir)
    mkdir(dstDir);
end

% Chép cả hai định dạng: .pdf cho LaTeX, .png cho slide và bản Word. Lọc theo
% tiền tố H (hình số liệu, make_figures) và bia_ (hình bìa, make_cover) để không
% kéo theo file rác ai đó để quên trong results/figures.
d = [dir(fullfile(srcDir, 'H*.pdf')); dir(fullfile(srcDir, 'H*.png')); ...
     dir(fullfile(srcDir, 'bia_*.pdf')); dir(fullfile(srcDir, 'bia_*.png'))];
if isempty(d)
    error('publish_figures:noFigures', ...
        'Khong co file H*.pdf hay H*.png nao trong %s. Chay make_figures truoc.', srcDir);
end

fprintf('%s\n  -> %s\n\n', srcDir, dstDir);
for i = 1:numel(d)
    src = fullfile(srcDir, d(i).name);
    dst = fullfile(dstDir, d(i).name);

    % copyfile trả về ok/msg thay vì ném lỗi khi thất bại. Không đọc ok thì một
    % file đích đang bị Acrobat khóa sẽ lặng lẽ không được cập nhật, và báo cáo
    % dịch ra vẫn có hình - hình CŨ.
    [ok, msg] = copyfile(src, dst, 'f');
    if ~ok
        error('publish_figures:copyFailed', ...
            'Khong chep duoc %s: %s', d(i).name, msg);
    end
    fprintf('  %-10s %7.1f KB\n', d(i).name, d(i).bytes/1024);
end

fprintf('\nDa cong bo %d file.\n', numel(d));
fprintf('Trong LaTeX goi bang \\includegraphics{Figures/H4_1}: ten file dung GACH DUOI\n');
fprintf('vi LaTeX cat phan mo rong o dau cham DAU TIEN, va khong ghi duoi file de\n');
fprintf('graphicx tu chon ban .pdf.\n');
