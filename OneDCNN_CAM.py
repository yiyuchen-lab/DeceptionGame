import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'

import tensorflow as tf
from tensorflow.keras import backend as K
from tensorflow.keras.models import load_model
from tf_explain.core.grad_cam import GradCAM
from functions.OneDCNN_Utils import *

from scipy.io import loadmat
from sklearn.model_selection import StratifiedKFold
import numpy as np
from alive_progress import alive_bar
import gc
import warnings

tf.compat.v1.logging.set_verbosity(tf.compat.v1.logging.ERROR)
warnings.filterwarnings("ignore", category=RuntimeWarning)

dataPath   = 'data/OneDCNN/data/'
modelPath  = 'data/OneDCNN/savedModel/'
resultPath = 'data/OneDCNN/savedResult/'
camPath    = 'data/OneDCNN/CAM/'
epochTypes = ['DecisionMaking'] #['Feedback', 'DecisionMaking']
creat_path(camPath)

for epo_type in epochTypes:

    # ============================     load data to get test-set   ============================
    data_mat    = loadmat('%s%s.mat' % (dataPath, epo_type))
    data_result = read_pkl('%s%s.pkl'% (resultPath, epo_type))

    # data_X:  [pariticipant x trials] x EEG channels x timesteps x role (Player 0, observer 1)
    data_X      = data_mat['data_X'][:, :, :, 0] if epo_type == 'DecisionMaking' else data_mat['data_X'][:, :, :, 1]
    data_y      = data_mat['data_y'].squeeze()
    data_ss_num = data_mat['pair_num'].squeeze()  # participant pair session number (1~23)
    data_ch     = make_string_array(data_mat['dataCh'].squeeze())
    className   = make_string_array(data_mat['className'].squeeze())

    bi_class      = data_result['className']
    channel_pairs = data_result['channel_pairs']
    n_chanPairs   = len(channel_pairs)
    n_biClass, n_subjs, n_folds = data_result['test_acc'].shape


    with alive_bar(int(n_biClass * n_subjs * n_folds), force_tty=True) as bar:

        model_path = locate_file('*%s*' % modelPath, folder=True)

        cams_class=[]

        for biClass_idx, classes in enumerate(bi_class):  # loop through binary classes

            cams_participant = []

            for subj in range(n_subjs):  # loop through participant

                classes_idx = np.array([(np.argwhere(className == c)).item() for c in classes])  # from numpy array to list
                selectClass = classes_idx if data_y.min() == 0 else classes_idx + 1

                data = select_data(data_X, data_y,
                                   data_sj_num=data_ss_num,
                                   select_sj_num=subj,
                                   select_classes=selectClass,
                                   select_timeIval=[50, -1] if epo_type == 'DecisionMaking' else [20, -1],  # post stimulus interval
                                   class_balance=True,
                                   seed=11)

                # prepare 10-fold CV split
                tenfold = StratifiedKFold(n_splits=n_folds)

                cams_fold = []

                for fold, (train_index, test_index) in enumerate(tenfold.split(data['x'], data['y'])):

                    # test set
                    test_split_x, test_split_y = data['x'][test_index], data['y'][test_index]
                    test_cat_X, test_cat_y, test_cat_chan = concat_chanTrial(test_split_x, test_split_y,
                                                                             chanPairs=channel_pairs,
                                                                             data_chan=data_ch)
                    test_x = np.swapaxes(test_cat_X, 1, 2).astype(np.float64)
                    test_y = tf.keras.utils.to_categorical(test_cat_y)

                    model     = load_model('%s%s/biClass%d_participant%d_fold%d/' % (modelPath,epo_type, biClass_idx, subj, fold))
                    explainer = GradCAM()
                    cams      = explainer.explain_raw((test_x, test_y), model, class_index=0, layer_name="conv4")

                    cams = np.array(cams)
                    cams = cams.reshape((n_chanPairs, test_split_y.size, -1))
                    cams = cams.mean(1)
                    cams_fold.append(cams)

                    bar()

                    # clear memory
                    del model
                    K.clear_session()
                    gc.collect()

                cams_participant.append(np.stack(cams_fold))

            cams_class.append(np.stack(cams_participant))

        data = {'cams': np.stack(cams_class), # (class x participant x fold x channelPair x layer output shape)
                'channel_pairs': channel_pairs,
                'binary_classes': bi_class}

        write_pkl('%s%s'%(camPath,epo_type), data)
        print("Caculated CAM for %s epochs is saved at location: '%s%s.pkl'" % (epo_type, camPath, epo_type))