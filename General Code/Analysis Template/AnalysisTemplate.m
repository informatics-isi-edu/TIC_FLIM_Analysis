%%  Analysis Template for FLIM data analysis
%  Update: 08/23/2021
%  Peiyu Wang

%  This is a template matlab program for data analysis.
%  Expected Data input: Exported GS files with Fast FLIM from Leica Falcon
%  System.
%  This program only analyzes 1 dataset with only 1 z input. Please adjust
%  to your need accordingly.

%  This dataset had 2 fluorescence detector channels, which generate 8 output channels:
%  First detector: SYTO59 staining dye.
%  Second detector: NADH autofluroesence.

%  The input also stored the Bright Field data in the BF file


%  Workflow anlaysis:
%  Data input ->  Mask Generation -> Thresholding -> Filtering ->
%  Metablic analysis based on masking -> data output.

%  Prerequisite: Function folder from the TIC collaborator github repository

close all; clear all;

addpath("Functions") %Change the path name to the location of "Function",
%or put Function folder on the same path as the matlab script
%% Input Variables

dataFolder = fullfile(pwd,"Data");  % dataFolder: location of the folder that contains Data
mask_ch = 1;                        % mask_ch: The channel which is used the generate the mask
%    notice please input as the matlab order, "ch0.tif" will be input as 1.

NADH_dec = 2;                       % The detector (not the channel) for NADH.
imageSize = 512;

%% Predifiniing variables.
G_sum = [];   % Summarizing the information of G
S_sum = [];   % Summarizing the information of S
Name = [];    % Stroing the names of the folder.
%% Data read in;
imageFolder = dir(dataFolder);

for i = 3: numel(imageFolder)
    %  i starts with three, as i=1 and 2 is the current directory and previous
    %  directory respectively, named ".", and ".."
    currentFolder = fullfile(imageFolder(i).folder,imageFolder(i).name);
    
    mask_folder = fullfile(currentFolder,"mask");  % create folder to store the masks
    if ~exist(mask_folder,'dir')
        mkdir(mask_folder)
    end
    
    image_file = dir(fullfile(currentFolder,"*.tif")); %imgFiles: all tif input files.
    BF_file = dir(fullfile(currentFolder,"BF","*.tif"));
    
    mask_org = imread(fullfile(image_file(mask_ch).folder,image_file(mask_ch).name));
    %  original mask image;
    
    int = imread(fullfile(image_file((NADH_dec-1)*4+1).folder,image_file((NADH_dec-1)*4+1).name));
    G = standardPhase( imread(fullfile(image_file((NADH_dec-1)*4+3).folder,image_file((NADH_dec-1)*4+3).name)));
    S = standardPhase( imread(fullfile(image_file((NADH_dec-1)*4+4).folder,image_file((NADH_dec-1)*4+4).name)));
    
    %  Data read in for int, G, and S; If necessaryly, addjust this according to
    %  your detector number for NADH.
    
    
    %% Creating Mask based on thresholding
    mask_img = zeros(size(int));
    
    mask_map = cat(3,ones(size(int))*0,ones(size(int))*1,ones(size(int))*1);
    %   Generate a cyan mask.  mask displayed as cyon for Selected threshold.
   
    disp('Thresholding Image to create Mask:')
    
    figure;set(gcf, 'units','normalized','outerposition',[0 0 1 1]);
    
    imagesc(mask_org); colormap(gca, hot); axis image; colorbar;
    
    hold on;
    p1 = imshow(mask_map); set(p1, 'AlphaData',mask_img);
    
    %% Creating pop up window for doing this
    judge_thresh = 1;
    while judge_thresh == 1
        
        temp_thresh_img = zeros(size(int));
        thresh = input("Please input threshold level: ");
        
        temp_thresh_img(mask_org<thresh) = 0;
        temp_thresh_img(mask_org>=thresh) = 1;
        set(p1, 'AlphaData',temp_thresh_img*0.5);
        
        promptMessage = "Do you want to reselect?(Y/N):";
        button1 = questdlg(promptMessage, 'Reselect threshold?', 'Yes', 'No', 'Yes');
        if strcmpi(button1, 'No')
            judge_thresh = 0;
        else
            set(p1, 'AlphaData',0);
        end
    end
    
    mask_img = temp_thresh_img;
    imwrite(mask_img,fullfile(currentFolder,"mask","mask_img.tif"));
    %  Saving the mask image to the mask file.
    %% Mask Generating based on drawing.
    mask_img = zeros(size(int));
    
    
    mask_map = cat(3,ones(size(int))*0,ones(size(int))*1,ones(size(int))*1);
    % mask displayed as cyon for future images.
    current_map = cat(3,ones(size(int))*1,ones(size(int))*0,ones(size(int))*1);
    % mask displayed as megenta for future images.
    
    disp('Drawing on image to create mask:')
    
    figure;set(gcf, 'units','normalized','outerposition',[0 0 1 1]);
    subplot(1,2,1);
    
    imagesc(mask_org); colormap(gca, hot); axis image; colorbar;
    
    subplot(1,2,2);
    
    imagesc(int); axis image; colormap(gca, jet); colorbar;
    hold on;
    p3 = imshow(mask_map); set(p3, 'AlphaData',mask_img);
    p4 = imshow(current_map); set(p4, 'AlphaData',mask_img);
    while 1
        subplot(1,2,1)
        H=drawfreehand('color','m','closed',true,'Linewidth',2);
        
        add_mask = H.createMask;
        set(p3, 'AlphaData',add_mask*0.55);
        
        button = questdlg("Add Another Region?", 'Next?', ...
            'Add to Current Mask', 'Redo','Done(with this round)',...
            'Add to Current Mask');
        if strcmp(button, 'Done(with this round)')
            mask_img(add_mask == 1) = 1;
            
            
            set(p3, 'AlphaData',0);
            set(p4, 'AlphaData',mask_img*0.55);
            
            break
        elseif strcmp(button, 'Add to Current Mask')
            mask_img(add_mask == 1) = 1;
            
            set(p3, 'AlphaData',0);
            set(p4, 'AlphaData',mask_img*0.55);
            
        else
            delete(H)
        end
    end
    imwrite(mask_img,fullfile(currentFolder,"mask","mask_img.tif"));
    %  Saving the mask image to the mask file.
    %% Filtering for NADH information
    
    org_struct = struct("int",int,"G",G,"S",S);
    
    % This org_struct stores information based on key value pairs:
    % the "int" is the key, that stores the value int inside the struct.
    % To access int, use org_struct.int;
    % This struct is the basic analysis unit for most of the Function
    % in the github repository function.
    
    % You can use the wavelet function that is provided in the Leica Falcon
    % systm. You can also use the median filter or the CNLM filter provided in
    % here.
    
    med_struct = medfiltPhasor(org_struct, 5);        % Perform median filtering with a window size of 5
    nlm_struct = nlmfiltPhasor(org_struct, 5, 9, 35); % Perform a nlm filting with a window size of 5, search window of 9, averaging level of 35
                                                      % Warning, CNLM takes quite some time to finish! 
                                                      
    figure; set(gcf, 'units','normalized','outerposition',[0 0 1 1]);
    subplot(2,2,1); imagesc(org_struct.int); axis image; colorbar; colormap(gca,jet); title("Intensity Map")
    subplot(2,2,2); plotPhasorFast(org_struct);  title("Original Phasor plot")
    subplot(2,2,3); plotPhasorFast(med_struct);  title("Median Filtered Phasor Plot")
    subplot(2,2,4); plotPhasorFast(nlm_struct);  title("CNLM Filtered Phasor Plot")
    
    
    
    %% Analysis of the data based on masked structure.
    
    % Usually filtering before masking is recommend, so that multiple masks
    % could be used without having to filter multiple times.
    
    % IF you don't have a mask, you can comment out the next 2 lines.
    
    mask_img = imread(fullfile(currentFolder,"mask","mask_img.tif"));
    org_struct = maskPhasorStruct(org_struct,mask_img); % If you don't have a mask, just comment out this procedure.
    
    [G_cur, S_cur] = findModePhasor(org_struct);  % Finding the mode of the phasors.
    % [G_cur, S_cur] = findCenPhasor(mask_struct); % Finding the center of the phasor.
    
    G_sum = cat(1,G_sum,G_cur);
    S_sum = cat(1,S_sum,S_cur);
    Name = cat(1, Name, imageFolder(i).name);
end

%% Advanced Analysis for NADH metabolism analysis 
[Mode_LEXT,G_int,S_int,tao] = lineExtensionMetabolism(G_sum, S_sum);
%   This is for the Line Extension metabolism analyis.
Mode_LR = LinearRegression_Analysis(G_sum, S_sum);
%   This is for the Linear Regression analysis.
%%
DataTable=table(Name,G_sum, S_sum, Mode_LEXT,G_int,S_int,tao,Mode_LR);
filefolder = 'Analysis06212021.xlsx';   % Name of the excel file.
writetable(DataTable,filefolder,'Sheet',1)
