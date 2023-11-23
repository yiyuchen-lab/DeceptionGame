
import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'

import tensorflow as tf
from tensorflow.keras import backend as K
from sklearn.model_selection import StratifiedKFold, StratifiedShuffleSplit
from tensorflow.keras.callbacks import EarlyStopping, LearningRateScheduler

from functions.OneDCNN_models import OneDCNN
from functions.OneDCNN_Utils import *

from scipy.io import loadmat
import numpy as np
from itertools import combinations
from alive_progress import alive_bar
import gc
import warnings
import datetime


warnings.filterwarnings("ignore", category=RuntimeWarning)
tf.compat.v1.logging.set_verbosity(tf.compat.v1.logging.ERROR)
physical_devices = tf.config.experimental.list_physical_devices('GPU')
tf.config.experimental.set_virtual_device_configuration(physical_devices[0],
                                                        [tf.config.experimental.VirtualDeviceConfiguration(memory_limit=2048)])

dataPath   = 'data/OneDCNN/data/'
modelPath  = 'data/OneDCNN/savedModel/'
resultPath = 'data/OneDCNN/savedResult/'
epochTypes = ['Feedback', 'DecisionMaking']

time_start = datetime.datetime.now()
creat_path(resultPath)

color_acc = '\033[94m'
color_cls = '\033[36m'
color_end = '\033[0m'


# -------------------------------- channel pair setup ----------------------------------

frontOccipital = np.array([['F9', 'PO3'], ['F7', 'P7'], ['F3', 'P3'], ['Fz', 'Pz'],
                             ['F4', 'P4'], ['F8', 'P8'], ['F10', 'PO4'], ['FC1', 'CP1'],
                             ['FC2', 'CP2']])

Xpattern       = np.array([['F9','PO4'], ['F7','P8'],['F3','P4'],['F4','P3'],
                           ['F8','P7'],['F10','PO3'],['FC1','CP2'],['FC2','CP1']])

circular       = np.array([['Cz', 'F9'], ['Cz', 'F7'], ['Cz', 'FC5'], ['Cz', 'T7'], ['Cz', 'CP5'],
                           ['Cz', 'P7'], ['Cz', 'O1'], ['Cz', 'O2'], ['Cz', 'P8'], ['Cz', 'CP6'],
                           ['Cz', 'T8'], ['Cz', 'FC6'], ['Cz', 'F8'], ['Cz', 'F10'],['Cz', 'Fp2']])

# -------------------------------- training parameters --------------------------------
save_model       = 1

learning_rate    = 0.001
cosine_annealing = 1
patience         = 30
max_epoch        = 100
n_folds          = 10


for epo_type in epochTypes:


    # -------------------------------- prepare path --------------------------------
    if save_model:
        creat_path("%s%s"%(modelPath,epo_type))
        print("Model saving is currently active. Model will be saved at the following location: '%s%s'" % (modelPath, epo_type))

    # -------------------------------- load data --------------------------------

    data_mat    = loadmat('%s%s.mat'%(dataPath,epo_type))
    # data_X:  [pariticipant x trials] x EEG channels x timesteps x role (Player 0, observer 1)
    data_X      = data_mat['data_X'][:, :, :, 0] if epo_type=='DecisionMaking' else data_mat['data_X'][:, :, :, 1]
    data_y      = data_mat['data_y'].squeeze()
    data_ss_num = data_mat['pair_num'].squeeze() # participant pair session number (1~23)

    data_ch   = make_string_array(data_mat['dataCh'].squeeze())
    className = make_string_array(data_mat['className'].squeeze())
    bi_class  = np.array(list(combinations(className,2)))

    channel_pairs = np.concatenate([frontOccipital,Xpattern]) if epo_type=='DecisionMaking' else circular

    n_subjs   = data_ss_num.max()
    n_chans   = data_ch.size
    n_biClass = bi_class.shape[0]

    train_accs = np.zeros([n_biClass, n_subjs, n_folds])
    valid_accs = np.zeros([n_biClass, n_subjs, n_folds])
    test_accs  = np.zeros([n_biClass, n_subjs, n_folds])

    with alive_bar(int(n_biClass * n_subjs * n_folds), force_tty=True) as bar:

        for biClass_idx, classes in enumerate(bi_class): # loop through binary classes

            for subj in range(n_subjs):  # loop through participant

                classes_idx = np.array([(np.argwhere(className == c)).item() for c in classes])  # from numpy array to list
                selectClass = classes_idx if data_y.min() == 0 else classes_idx + 1

                data = select_data(data_X, data_y,
                                   data_sj_num=data_ss_num,
                                   select_sj_num=subj,
                                   select_classes=selectClass,
                                   select_timeIval=[50,-1] if epo_type=='DecisionMaking' else [20,-1], # post stimulus interval
                                   class_balance=True,
                                   seed=11)
                # prepare 10-fold CV split
                tenfold = StratifiedKFold(n_splits=n_folds)
                # parepare early stop split (~10% of original data)
                EarlyStopSplit = StratifiedShuffleSplit(n_splits=1, test_size=(1 / 9), random_state=11)

                # -------------------------------- ten-fold cross validation  --------------------------------

                for fold, (train_index, test_index) in enumerate(tenfold.split(data['x'], data['y'])):

                    # get train - test set (X: trials x 30 EEGchannels x timepoints)
                    train_ori_x, train_ori_y = data['x'][train_index], data['y'][train_index]
                    test_split_x, test_split_y = data['x'][test_index], data['y'][test_index]

                    # get train - validation set
                    train_idx, valid_idx = next(EarlyStopSplit.split(train_ori_x, train_ori_y))
                    train_split_x, train_split_y = train_ori_x[train_idx], train_ori_y[train_idx]
                    valid_split_x, valid_split_y = train_ori_x[valid_idx], train_ori_y[valid_idx]

                    # concatenate trials of each channel pair (X: trials x 2 EEGchannels x timepoints)
                    train_cat_X, train_cat_y, train_cat_chan = concat_chanTrial(valid_split_x, valid_split_y, chanPairs=channel_pairs, data_chan=data_ch)
                    valid_cat_X, valid_cat_y, valid_cat_chan = concat_chanTrial(valid_split_x, valid_split_y, chanPairs=channel_pairs, data_chan=data_ch)
                    test_cat_X, test_cat_y, test_cat_chan = concat_chanTrial(test_split_x, test_split_y, chanPairs=channel_pairs, data_chan=data_ch)

                    # one hot label
                    train_y = tf.keras.utils.to_categorical(train_cat_y)
                    valid_y = tf.keras.utils.to_categorical(valid_cat_y)
                    test_y  = tf.keras.utils.to_categorical(test_cat_y)

                    # swap X axes for model input (X: trials x timepoints x 2 EEGchannels)
                    train_x = np.swapaxes(train_cat_X, 1, 2).astype(np.float64)
                    valid_x = np.swapaxes(valid_cat_X, 1, 2).astype(np.float64)
                    test_x  = np.swapaxes(test_cat_X, 1, 2).astype(np.float64)

                    # setup model
                    model         = OneDCNN(n_timepoints=train_x.shape[1])
                    loss          = tf.keras.losses.categorical_crossentropy
                    optimizer     = tf.keras.optimizers.Adam(learning_rate=learning_rate)
                    cos_decay     = tf.keras.optimizers.schedules.CosineDecay(initial_learning_rate=learning_rate, decay_steps=max_epoch - 1)
                    lr_scheduler  = LearningRateScheduler(cos_decay, verbose=False)
                    earlystopping = EarlyStopping(monitor='val_accuracy',
                                                  min_delta=learning_rate,
                                                  patience=patience,
                                                  restore_best_weights=True,
                                                  verbose=0)
                    callbacks     = [lr_scheduler,earlystopping]
                    model.compile(loss=loss, optimizer=optimizer, metrics=[tf.keras.metrics.AUC(name='auc')])

                    # start training
                    histoty = model.fit(train_x, train_y,
                                        epochs=max_epoch,
                                        batch_size=64,
                                        validation_data=(valid_x, valid_y),
                                        callbacks=callbacks,
                                        verbose=0)

                    # store model if needed
                    if save_model: model.save('%s%s/biClass%d_participant%d_fold%d' % (modelPath, epo_type, biClass_idx, subj, fold))


                    # store results
                    _, train_accs[biClass_idx, subj, fold] = model.evaluate(train_x, train_y, verbose=0)
                    _, valid_accs[biClass_idx, subj, fold] = model.evaluate(valid_x, valid_y, verbose=0)
                    _,  test_accs[biClass_idx, subj, fold] = model.evaluate(test_x,  test_y,  verbose=0)

                    # clear memory
                    del model
                    K.clear_session()
                    gc.collect()

                    bar()
                    # << end of fold loop

                print('Class [%s%s%s] Participant [%d]: '
                      'train [%s%.2f%s], valid [%s%.2f%s], test [%s%.2f%s]' % (color_cls,
                                                                              '-'.join(classes),
                                                                              color_end,
                                                                              subj,
                                                                              color_acc,
                                                                              train_accs[biClass_idx, subj].mean(),
                                                                              color_end,
                                                                              color_acc,
                                                                              valid_accs[biClass_idx, subj].mean(),
                                                                              color_end,
                                                                              color_acc,
                                                                              test_accs[biClass_idx, subj].mean(),
                                                                              color_end
                                                                              ))
                # << end of participant loop
            print('---------------------------------------------------------------')
            print('Class [%s%s%s] Overall: '
                  'train [%s%.2f%s], valid [%s%.2f%s], test [%s%.2f%s]' % (color_cls,
                                                                          '-'.join(classes),
                                                                          color_end,
                                                                          color_acc,
                                                                          train_accs[biClass_idx].mean(),
                                                                          color_end,
                                                                          color_acc,
                                                                          valid_accs[biClass_idx].mean(),
                                                                          color_end,
                                                                          color_acc,
                                                                          test_accs[biClass_idx].mean(),
                                                                          color_end))
    data={'channel_pairs':channel_pairs,
          'className':bi_class,
          'train_acc':train_accs,
          'valid_acc':valid_accs,
          'test_acc':test_accs}

    time_end = datetime.datetime.now()
    [hours, mins, secs] = str(time_end - time_start).split('.')[0].split(':')
    write_pkl('%s%s' % (resultPath,epo_type), data)
    print('---------------------------------------------------------------')
    print("time spent for %s: %s hours %s minutes %s seconds."%(epo_type,hours,mins,secs))
    print("Classification results is saved at the location '%s%s.pkl'" % (resultPath, epo_type))
    print("OneDCNN trained model is saved at the location '%s%s/'" % (modelPath, epo_type))


