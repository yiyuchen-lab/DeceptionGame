import numpy as np
import pickle
import os
import fnmatch
import random


def select_class(data_x, data_y, labels):
    """
    :param float               data_x : trial x channel x time
    :param ndarray             data_y : string/numerical label x 1
    :param list of str or int  labels : list of string/numerical class names
    """
    index_preserve = np.array([])
    for cls in labels:
        indices = np.argwhere(data_y == cls)
        index_preserve = np.append(index_preserve, indices)

    index_preserve = index_preserve.astype(int)

    return data_x[index_preserve, :, :], data_y[index_preserve], index_preserve


def balance_class(data_x, data_y, seed=None):
    """
    :param ndarray    data_x : trial x channel x time
    :param ndarray    data_y : string/numerical label x 1
    :param int        seed : seed for random choice
    """
    # print("random seed:", np.random.get_state()[1][0])

    # get minimum trial numbers
    class_name, class_sample = np.unique(data_y, return_counts=True)
    target_size = class_sample.min()

    class_trial_idx = []
    class_rand_trial = np.array([], dtype=int)

    for i, c in enumerate(class_name):
        # trial indices from classes to be balanced
        class_trial_idx.append(np.argwhere(data_y == c))
        # randomly sample trials from classes to be balanced
        if seed is not None:
            np.random.seed(seed)
        rand_sample = np.random.choice(class_trial_idx[i].reshape(-1), target_size, replace=False)
        class_rand_trial = np.append(class_rand_trial, rand_sample.reshape(-1))

    return data_x[class_rand_trial], data_y[class_rand_trial], class_rand_trial



def binary_class_label(y):

    y_out = y.copy()
    label_value = np.unique(y)

    if len(label_value) == 2:
        y_out[np.argwhere(y == label_value[0])] = 0
        y_out[np.argwhere(y == label_value[1])] = 1

    return y_out



def make_string_array(array):

    """
    used when data imported from Matlab string cell array using scipy.io

    :param  numpy.ndarray array: array([array(['string1'],dtype='<U7'), [array(['string2'],dtype='<U7'),], dtype=object)
    :return numpy.array   array: array(['string1','string2'], dtype=object)
    """

    array_out = np.array([], dtype=object)
    for i, string in enumerate(array):
        array_out = np.append(array_out, string[0])
    array_out = array_out.astype('str')
    return array_out



def write_pkl(export_path, data):

    with open(export_path + '.pkl', 'wb') as f:
        pickle.dump(data, f)


def read_pkl(file):

    with open(file, 'rb') as f:
        data = pickle.load(f)

    return data


def creat_path(dir_name):

    if not os.path.exists(dir_name):
        os.makedirs(dir_name)
        print("Directory ", dir_name, " Created ")
    else:
        print("Directory ", dir_name, " already exists")


def select_channels(data_x, select_ch, data_ch=None, chan_dim = 1):

    if isinstance(select_ch[0],str):
        assert  data_ch is not None
        channels = np.char.lower(data_ch)
        select_list = np.char.lower(select_ch)
        keep_idx = [i for i, chan in enumerate(channels) for s in select_list if s == chan]
        return np.take(data_x, keep_idx, axis=chan_dim), keep_idx

    elif isinstance(select_ch[0],int):
        return np.take(data_x, select_ch, axis=chan_dim), select_ch

    else:
        raise ValueError("unknown data type in 'select_ch'")


def select_data(data_x,
                data_y_num,
                data_sj_num,
                select_sj_num,
                select_classes=None,
                select_channel=None,
                select_timeIval=None,
                data_y_str=None,
                data_ch = None,
                class_balance=True,
                seed=None):

    data_out = dict()

    # select subject data
    sj_idx             = np.argwhere(data_sj_num == select_sj_num + 1).reshape(-1)
    sj_x               = data_x[sj_idx]
    sj_y_num           = data_y_num[sj_idx]
    data_out['sj_idx'] = sj_idx

    # select class
    if select_classes is not None:
        x, y_num, ind_selected = select_class(sj_x, sj_y_num, select_classes)
        data_out['cls_idx']    = ind_selected
    else:
        x = sj_x
        y_num = sj_y_num

    # binary class
    if np.array_equal(np.unique(y_num), [0, 1]):
        y_binary  = y_num
    else:
        y_binary  = binary_class_label(y_num)

    # select channel
    if select_channel is not None:
        if data_ch is not None:
            x_chan, idx = select_channels(x, select_channel, data_ch)
            data_out['ch_idx'] = idx
        else:
            x_chan = select_channels(x, select_channel)
    else:
        x_chan = x

    # whether classes need to be balanced
    if class_balance:
        x_bl, y_bl, ind_bl = balance_class(x_chan, y_binary, seed=seed)

        # convert data precision for pytorch
        data_out['x'] = x_bl.astype(np.float32)
        data_out['y'] = y_bl.astype(np.int32)

        data_out['bl_idx'] = ind_bl

        # check if data_y_str is provided
        if data_y_str is not None:
            y_str_sj = data_y_str[sj_idx]
            y_str_cl = y_str_sj[ind_selected]
            data_out['y_str'] = y_str_cl[ind_bl]

    else:
        data_out['x'] = x_chan.astype(np.float32)
        data_out['y'] = y_binary.astype(np.long)



        if data_y_str is not None:
            y_str_sj = data_y_str[sj_idx]
            y_str_cl = y_str_sj[ind_selected]
            data_out['y_str'] = y_str_cl


   # select time interval
    if select_timeIval is not None:
        data_out['x']  = select_time_points(data_out['x'], select_timeIval)


    return data_out


def concat_chanTrial(data_x, data_y, chanPairs, data_chan):
    """
    :param data_x:  EEG data to be converted (trials x EEG channels x timepoints)
    :param data_y:  event label data to be converted (trials x EEG channels)
    :param chanPairs:  list of channel pairs
    :param data_chan:  original channel information of EEG data
    :return:
    """
    chan_data = []
    chan_pair = []
    for chan in chanPairs:
        d, _ = select_channels(data_x, chan, data_ch=data_chan)
        chan_data.append(d)
        chan_pair.append(np.tile(chan,(d.shape[0],1)))

    X_concat    = np.vstack(chan_data)
    y_concat    = np.tile(data_y,len(chanPairs))
    chan_concat = np.concatenate(chan_pair)
    return  X_concat, y_concat, chan_concat



def select_time_points(dataset, interval):
    """
    :param np.array dataset: [trials, chans, time_points]
    :param list interval: index of start and end
    :return: np.array data_out: data with selected interval
    """

    data_out = dataset.copy()
    start, end = interval
    data_out = data_out[:, :, start:end]

    return data_out


def get_fname_from_fullpath(path, level=-1):

    portion_of_paths = path.split('/')
    fname = portion_of_paths[level]
    return fname

def change_bar_width(ax, new_value):
    for patch in ax.patches:
        current_width = patch.get_width()
        diff = current_width - new_value
        patch.set_width(new_value) # change the bar width
        patch.set_x(patch.get_x() + diff * .5) # recenter the bar
