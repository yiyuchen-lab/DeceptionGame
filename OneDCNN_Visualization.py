from matplotlib import pyplot as plt
import seaborn as sns
import pandas as pd
import numpy as np

from functions.OneDCNN_Utils import read_pkl
from functions.OneDCNN_Utils import change_bar_width
camPath    = 'data/OneDCNN/CAM/'
resultPath = 'data/OneDCNN/savedResult/'
figPath    = 'fig/'
epochTypes = ['Feedback', 'DecisionMaking']

for epo_type in epochTypes:

    cam    = read_pkl('%s%s.pkl'%(camPath,epo_type))
    result = read_pkl('%s%s.pkl'%(resultPath,epo_type))

    biClass  = ['_'.join(i) for i in cam['binary_classes']]
    chanPair = ['_'.join(i) for i in cam['channel_pairs']]
    test_acc = result['test_acc'].mean(-1) # get mean accuracy across folds

    n_biClass, n_subj, n_fold, n_chanPair, n_output = cam['cams'].shape

    cam_data = pd.DataFrame({'grad-CAM': np.stack(cam['cams']).flatten(),
                             'chanPair': np.tile(np.repeat(chanPair, n_output),n_biClass*n_subj*n_fold),
                             'output': np.tile(np.arange(n_output), n_chanPair*n_fold*n_subj*n_biClass),
                             'fold': np.tile(np.repeat(np.arange(n_fold), n_chanPair*n_output), n_subj*n_biClass),
                             'participant': np.tile(np.repeat(np.arange(n_subj), n_fold*n_chanPair*n_output), n_biClass),
                             'binary classes': np.repeat(biClass,n_subj*n_fold*n_chanPair*n_output)
                            })

    acc_data = pd.DataFrame({'accuracy': test_acc.flatten(),
                             'participant': np.tile(np.arange(n_subj), n_biClass),
                             'binary classes': np.repeat(biClass,n_subj)})

    #  =================================    plot line-CAM  ================================

    prestim = 0#-500 if epo_type == 'DecisionMaking' else -200
    posstim = 3000 if epo_type == 'DecisionMaking' else 1000
    tick_spacing = 500

    num_of_ticks = int((posstim - prestim) / tick_spacing)
    xticklabel = np.linspace(prestim, posstim, num_of_ticks + 1).astype(int)
    ratio = (posstim - prestim) / n_output
    output_to_time = xticklabel / ratio

    # normalize data
    d_norm_by_participant = cam_data.drop(columns='grad-CAM')
    d_norm_by_participant.insert(0, 'grad-CAM', cam_data.groupby(['binary classes', 'participant', 'fold'])['grad-CAM'].transform(
                                  lambda x: (x - x.min()) / (x.max() - x.min())))
    plt.figure(figsize=(6, 3))
    pal = sns.color_palette("Blues_d") if epo_type == 'DecisionMaking' else [sns.color_palette("Blues_d")[3]]
    sns.lineplot(x='output', y='grad-CAM', data=d_norm_by_participant, hue='binary classes', palette=pal)
    plt.legend(ncol=3, loc='upper right', fontsize='x-small')
    plt.xticks(output_to_time, xticklabel)
    plt.xlabel('time (ms)')
    plt.grid(True)
    plt.tight_layout()
    plt.savefig('%s%s/Linplot_CAM.pdf' % (figPath, epo_type))
    plt.close('all')

    # ============================= plot classification accuracy ===============================
    bar_ylim = [0.35, 0.8] if epo_type == 'DecisionMaking' else [0.5,0.9]
    fig_size = (6,5) if epo_type == 'DecisionMaking' else (3,5)

    plt.figure(figsize=fig_size)
    dots = sns.stripplot(data=acc_data, x='binary classes', y='accuracy',color='white', edgecolor='black',
                         linewidth=0.5, label='individual accuracy')
    bar = sns.barplot(data=acc_data,x='binary classes', y='accuracy', dodge=False, ci=None, palette=sns.color_palette("Blues_d"))
    if epo_type == 'Feedback':
        change_bar_width(bar, 0.35)
    else:
        plt.xticks(rotation=10)
    plt.ylim(bar_ylim)
    plt.grid(axis='y')
    plt.tight_layout()
    plt.savefig('%s%s/Barplot_classification_result.pdf' % (figPath, epo_type))


