clear all 
close all
load('../data/opt.mat')


global BBCI_PRINTER EEG_FIG_DIR
BBCI_PRINTER=1;
EEG_FIG_DIR=opt.figure_path;



for type = 1%1:numel(opt.epoch_type)

    clear epos statIval

    fprintf('Calculating ERP for %s epochs ...\n',  opt.epoch_type{type})

    %% load data
    data_path = [opt.preprocessedData_path opt.epoch_type{type}];
    filenames = dir([data_path '/*.mat']);
    
    epos={};
    for file = 1:numel(filenames)
        load([data_path '/' filenames(file).name], opt.session_role{type});
        epos{file} = eval(opt.session_role{type});
    end
    
    if strcmp(opt.epoch_type{type},'DecisionMaking')

        %colors   = {'#0072BD', '#4DBEEE', '#A2142F', '#D95319',};
        colors = [0, 114, 189; 77, 190, 238;
                  162, 20, 47; 217, 83, 25];
        colors = colors/255;
        IvalColor = [repmat(0.8, 4,3);repmat(0.6,1,3)];

        statIval = {[180,200; 260,290; 320,340; 440,520],...
                    [180,200; 260,290; 320,340; 490,520]};

        % remove mixed comparisons 
        classPair = nchoosek(sort(opt.eegmarker_label.showCard(end:-1:1)),2);
        removeCls = {{'sponL','instT'},{'sponT','instL'}};
        removeIdx = cellfun(@(c) find(all(ismember(classPair,c),2)), removeCls);
        keepIdx   = setdiff(1:size(classPair,1), removeIdx);
        classPair = classPair(keepIdx,:);


        idx = find(cellfun(@(c) any(ismember(c.clab,'POz')), epos));
        if ~isempty(idx) 
            epos{idx}.clab{ismember(epos{idx}.clab,'POz')} = 'PO4';
        end
        
        %% lineplot of ERP for all classes 
        epos     = cellfun(@(s) {proc_selectIval(s,[-200,1000])}, epos);
        epos_erp = cellfun(@(s) {proc_average(s)}, epos);

        grand_erp = proc_grandAverage(epos_erp,'average','weighted');
        ERP_sort  = proc_selectClasses(grand_erp,{'sponL','sponT','instL','instT'});
       
        ERP_sort.refIval = [-200,0];
        line_statIval    = [180,200; 260,290; 320,340;440,490; 490,520];

        fig_set(1,'clf',1,'gridsize',[5,3],'name','lineplot')
       
        H.channel = plotChannel(ERP_sort,'Fz',...
                                 'xGrid','off','yGrid','off',...
                                 'YUnit','\muV','legend',0,...
                                 'PlotRef',1,'LineWidthOrder',3,...
                                 'TitleFontSize',35,'AxisTitleFontSize',20);
        hold on; 
        % color the interval used for scalp evolution map
        for cc= 1:size(line_statIval,1)
            grid_markIval(line_statIval(cc,:), 'Fz', IvalColor(cc,:));
        end
        
        % incease font size
        h.leg= legend(H.channel.plot, ERP_sort.className,'FontSize',15,...
                      'Location','northwest');
        ax = gca;
        ax.YAxis.FontSize = 14;
        ax.XAxis.FontSize = 14;

        % temporarily change the colororlor for visualization
        defult_color= get(gca,'colororder');
        colororder(colors)
        hold off
        printFigure([opt.epoch_type{type} '/plotchannel_Fz_4classes'],...
                         'format','pdf')
        colororder(defult_color)
        close all
        

        %% select binary class for binary contrast visualization
        for bi_class = 1:size(classPair,1)
            
            %% calculate binary ERP and statistics
            
            % individual
            bi_epos = cellfun(@(s) {proc_selectClasses(s,classPair(bi_class,:))}, epos);
            bi_ERP  = cellfun(@(s) {proc_selectClasses(s,classPair(bi_class,:))}, epos_erp);
            bi_R    = cellfun(@(s) {proc_r_square_signed(s)}, bi_epos);

            
            % grand average
            bi_grandERP = proc_grandAverage(bi_ERP,'average','weighted');
            bi_grandR   = proc_grandAverage2(bi_R,'bonferroni',1);
            
        
            %% visualize ERP 
            ival_idx      = any(cellfun(@(c) contains(c,'spon'),classPair(bi_class,:))); 
            coloroder_idx = cellfun(@(c) find(strcmp(c,ERP_sort.className)),...
                                        classPair(bi_class,:));
            coloroder_bi   = colors(coloroder_idx,:);

            
            fig_set(1,'clf',1, 'gridsize',[3 3],'Name', 'ScalpEvalutionOfERP');
            mnt = getElectrodePositions(bi_grandERP.clab);
            H= scalpEvolutionPlusChannel(bi_grandERP, mnt, [], ...
                                         statIval{ival_idx+1}, defopt_scalp_erp,...
                                         'extrapolate',1,...
                                         'colorOrder',coloroder_bi,...
                                         'extrapolateToMean',0,...
                                         'TitleFontSize',17,'AxisTitleFontSize',15, ...
                                         'colAx',[-3.5 3.5]);
            colororder(coloroder_bi)
            cbpos_up   = get(H.cb(1), 'Position');   
            cbpos_down = get(H.cb(2), 'Position');
            set(H.cb(2),'visible','off')
            
            length_ratio = 0.7;
            height_shrink = (2.4*length_ratio);
            bottom_offset = 2.4-height_shrink;
            new_cobpos = [cbpos_down(1) 
                          cbpos_down(2)+((bottom_offset*cbpos_down(4))/2)
                          cbpos_down(3) 
                          cbpos_down(4)*height_shrink];
            
            set(H.cb(1),'position',new_cobpos)
            printFigure(sprintf('%s/classWiseERP[%s]',opt.epoch_type{type},...
                        char(join(classPair(bi_class,:),'_vs_'))),...
                        'format','pdf')
               


            %% visualize P value of t-statistics 

            bi_p   = bi_grandR;
            bi_p.x = -log10(max(bi_grandR.p,eps)) .* sign(bi_grandR.x);
            bi_p.yUnit = '-log_{10}(p)';
            bi_p.className = join(bi_grandERP.className,' vs. ');
            
            ct     = log10([0.001 0.005 0.01 0.05 0.1]);
            alpha  = 0.05;
            
            fig_set(1, 'clf',1, 'gridsize',[2 3],'name','ScalpEvalutionOfPvalue')
            H2 = scalpEvolution(bi_p, mnt, statIval{ival_idx+1}, defopt_scalp_r2, ...
                                'contour', sort([-ct ct]), ...
                                'markcontour', [-1 1]*log10(alpha), ...
                                'markcontour_lineprop', {'linewidth',3});
            printFigure(sprintf('%s/classWisePvalue[%s]',opt.epoch_type{type},...
                        char(join(classPair(bi_class,:),'_vs_'))),...
                        'format','pdf')

            

        end
        
        

    elseif strcmp(opt.epoch_type{type},'Feedback')

        %% calculate ERP and statistics
        
        % individual
        % change the order of class and make it [Incorrect-Correct] in
        % paired t-test
        epos     = cellfun(@(s) {proc_selectClasses(s,{'Incorrect', ...
                   'Correct'})}, epos); 
        epos_R   = cellfun(@(s) {proc_r_square_signed(s)}, epos);
        epos_ERP = cellfun(@(s) {proc_average(s)}, epos);
        
        % grand average
        grandERP = proc_grandAverage(epos_ERP,'average','weighted');
        grandR   = proc_grandAverage2(epos_R,'bonferroni',1);
        
        statIval = [250, 430; 430 550; 550 750];
        IvalColor = [repmat(0.8, 1,3);repmat(0.6,1,3);repmat(0.8, 1,3)];

        %% lineplot of ERP
        fig_set(1,'clf',1,'gridsize',[5,3],'name','lineplot')
       
        H.channel = plotChannel(grandERP,'Cz',... 
                                 'xGrid','off','yGrid','off',...
                                 'YUnit','\muV','legend',0,...
                                 'PlotRef',1,'LineWidthOrder',3,...
                                 'TitleFontSize',35,'AxisTitleFontSize',20);
        hold on;
    
        % color the interval used for scalp evolution map
        for cc= 1:size(statIval,1)
            grid_markIval(statIval(cc,:), 'Cz', IvalColor(cc,:));
        end

        % incease font size
        h.leg= legend(H.channel.plot, grandERP.className,'FontSize',15,...
                      'Location','northwest');
        ax = gca;
        ax.YAxis.FontSize = 14;
        ax.XAxis.FontSize = 14;
        colororder([0.9,0.5,0;0.35,0.35,0.35])

        printFigure([opt.epoch_type{type} '/plotchannel_Cz_2classes'],...
                         'format','pdf')
        
        

        
        %% scalp evolution of ERP 
        
        fig_set(1,'clf',1, 'gridsize',[2 3],'Name', 'ScalpEvalutionOfERP');
        mnt = getElectrodePositions(grandERP.clab);
        H= scalpEvolutionPlusChannel(grandERP, mnt, [], ...
                                     statIval, defopt_scalp_erp,...
                                     'extrapolate',1,...
                                     'extrapolateToMean',0,...
                                     'TitleFontSize',17,'AxisTitleFontSize',15, ...
                                     'colAx',[-5 5]);
       
        cbpos_up   = get(H.cb(1), 'Position');   
        cbpos_down = get(H.cb(2), 'Position');
        set(H.cb(2),'visible','off')
        
        length_ratio = 0.7;
        height_shrink = (2.4*length_ratio);
        bottom_offset = 2.4-height_shrink;
        new_cobpos = [cbpos_down(1) 
                      cbpos_down(2)+((bottom_offset*cbpos_down(4))/2)
                      cbpos_down(3) 
                      cbpos_down(4)*height_shrink];
        
        set(H.cb(1),'position',new_cobpos)
        printFigure(sprintf('%s/ERP[%s]',opt.epoch_type{type},...
                    char(join(grandERP.className,'_vs_'))),...
                    'format','pdf')


        %% visualize P value of t-statistics

        

        grandP   = grandR;
        grandP.x = -log10(max(grandR.p,eps)) .* sign(grandR.x);
        grandP.yUnit = '-log_{10}(p)';
        grandP.className = join(grandERP.className,' vs. ');
        
        ct     = log10([0.001 0.005 0.01 0.05 0.1]);
        alpha  = 0.05;
        
        fig_set(1,'clf',1, 'gridsize',[2 3],'name','ScalpEvalutionOfPvalue')
        H2 = scalpEvolution(grandP, mnt, statIval, defopt_scalp_r2, ...
                            'contour', sort([-ct ct]), ...
                            'markcontour', [-1 1]*log10(alpha), ...
                            'markcontour_lineprop', {'linewidth',3});
        printFigure(sprintf('%s/Pvalue[%s]',opt.epoch_type{type},...
                    char(join(grandERP.className,'_vs_'))),...
                    'format','pdf')

    end

end

close all




