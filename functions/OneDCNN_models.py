"""
A 1D CNN for high accuracy classiﬁcation in motor imagery EEG-based brain-computer interface
Journal of Neural Engineering (https://doi.org/10.1088/1741-2552/ac4430)
Copyright (C) 2022  Francesco Mattioli, Gianluca Baldassarre, Camillo Porcaro

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
"""
import tensorflow as tf

from tensorflow.keras.models import Model
from tensorflow.keras.layers import Dense, Dropout
from tensorflow.keras.layers import Conv1D, AveragePooling1D
from tensorflow.keras.layers import BatchNormalization
from tensorflow.keras.layers import SpatialDropout1D
from tensorflow.keras.layers import Input, Flatten
from tensorflow.keras import backend as K



def OneDCNN(n_timepoints =300, nb_classes=2, kerLength1=20, kerLength2=6, drop_rate=0.5):

    input_layer = Input(shape = (n_timepoints, 2), name='input')

    conv1 = Conv1D(filters=32, kernel_size=kerLength1, activation='relu', padding= "same", name='conv1')(input_layer)
    conv1 = BatchNormalization(name='conv1_BN')(conv1)

    conv2 = Conv1D(filters=32, kernel_size=kerLength1, activation='relu', padding= "valid", name='conv2')(conv1)
    conv2 = BatchNormalization(name='conv2_BN')(conv2)
    conv2 = SpatialDropout1D(drop_rate, name='conv2_DO')(conv2)

    conv3 = Conv1D(filters=32, kernel_size=kerLength2, activation='relu', padding= "valid", name='conv3')(conv2)
    conv3 = AveragePooling1D(pool_size=2,name='conv3_AP')(conv3)

    conv4 = Conv1D(filters=32, kernel_size=kerLength2, activation='relu',padding= "valid", name='conv4')(conv3)
    conv4 = SpatialDropout1D(drop_rate,name='conv4_DO')(conv4)

    flatten = Flatten()(conv4)

    dense1 = Dense(296, activation='relu', name='dense1')(flatten)
    dense1 = Dropout(drop_rate, name='dense1_DO')(dense1)

    dense2 = Dense(148, activation='relu', name='dense2')(dense1)
    dense2 = Dropout(drop_rate, name='dense2_DO')(dense2)

    dense3 = Dense(74, activation='relu', name='dense3')(dense2)
    dense3 = Dropout(drop_rate, name='dense3_DO')(dense3)

    output_layer = Dense(nb_classes, activation='softmax',name='softmax')(dense3)

    return Model(inputs=input_layer, outputs=output_layer)

class HopefullNet(tf.keras.Model):
    """
    Original HopeFullNet
    """
    def __init__(self, input_shape=(None, 300,2),kernal_1=20, kernal_2=6):
        super(HopefullNet, self).__init__()

        self.kernel_size_0 = kernal_1 #12 #20
        self.kernel_size_1 = kernal_2 #4 #6
        self.drop_rate = 0.5

        # self.input_layer = tf.keras.layers.Input(shape=input_shape)

        self.conv1 = tf.keras.layers.Conv1D(filters=32,
                                            kernel_size=self.kernel_size_0,
                                            activation='relu',
                                            padding= "same",
                                            input_shape=input_shape)
        self.batch_n_1 = tf.keras.layers.BatchNormalization()

        self.conv2 = tf.keras.layers.Conv1D(filters=32,
                                            kernel_size=self.kernel_size_0,
                                            activation='relu',
                                            padding= "valid")
        self.batch_n_2 = tf.keras.layers.BatchNormalization()
        self.spatial_drop_1 = tf.keras.layers.SpatialDropout1D(self.drop_rate)

        self.conv3 = tf.keras.layers.Conv1D(filters=32,
                                            kernel_size=self.kernel_size_1,
                                            activation='relu',
                                            padding= "valid")
        self.avg_pool1 = tf.keras.layers.AvgPool1D(pool_size=2)

        self.conv4 = tf.keras.layers.Conv1D(filters=32,
                                            kernel_size=self.kernel_size_1,
                                            activation='relu',
                                            padding= "valid")
        self.spatial_drop_2 = tf.keras.layers.SpatialDropout1D(self.drop_rate)
        self.flat = tf.keras.layers.Flatten()

        self.dense1 = tf.keras.layers.Dense(296, activation='relu')
        self.dropout1 = tf.keras.layers.Dropout(self.drop_rate)
        self.dense2 = tf.keras.layers.Dense(148, activation='relu')
        self.dropout2 = tf.keras.layers.Dropout(self.drop_rate)
        self.dense3 = tf.keras.layers.Dense(74, activation='relu')
        self.dropout3 = tf.keras.layers.Dropout(self.drop_rate)
        self.out = tf.keras.layers.Dense(2, activation='softmax')

    def call(self, input_tensor):

        conv1 = self.conv1(input_tensor)
        batch_n_1 = self.batch_n_1(conv1)

        conv2 = self.conv2(batch_n_1)
        batch_n_2 = self.batch_n_2(conv2)
        spatial_drop_1 = self.spatial_drop_1(batch_n_2)

        conv3 = self.conv3(spatial_drop_1)
        avg_pool1 = self.avg_pool1(conv3)

        conv4 = self.conv4(avg_pool1)
        spatial_drop_2 = self.spatial_drop_2(conv4)

        flat = self.flat(spatial_drop_2)
        dense1 = self.dense1(flat)
        dropout1 = self.dropout1(dense1)

        dense2 = self.dense2(dropout1)
        dropout2 = self.dropout2(dense2)

        dense3 = self.dense3(dropout2)
        dropout3 = self.dropout3(dense3)


        return self.out(dropout3)

    def train_step(mixed_inputs, targets_a, targets_b, lam):
        with tf.GradientTape() as tape:
            # Feed forward
            predictions = model(mixed_inputs, training=True)
            # Calculate loss
            loss = mixup_criterion(predictions, targets_a, targets_b, lam)
        # Calculate gradients
        gradients = tape.gradient(loss, model.trainable_variables)
        # Update weights
        optimizer.apply_gradients(zip(gradients, model.trainable_variables))
        # Update accuracy
        accuracy_metric.update_state(targets_a, predictions)

        return loss


class HopefullNet_HBN(tf.keras.Model):
    """
    HopeFullNet without batch normalization
    """
    def __init__(self):
        super(HopefullNet_HBN, self).__init__()

        self.kernel_size_0 = 20
        self.kernel_size_1 = 6
        self.drop_rate = 0.5

        self.conv1 = tf.keras.layers.Conv1D(filters=32,
                                            kernel_size=self.kernel_size_0,
                                            activation='relu',
                                            padding= "same",
                                            input_shape=(640, 2))
        self.conv2 = tf.keras.layers.Conv1D(filters=32,
                                            kernel_size=self.kernel_size_0,
                                            activation='relu',
                                            padding= "valid")
        self.spatial_drop_1 = tf.keras.layers.SpatialDropout1D(self.drop_rate)
        self.conv3 = tf.keras.layers.Conv1D(filters=32,
                                            kernel_size=self.kernel_size_1,
                                            activation='relu',
                                            padding= "valid")
        self.avg_pool1 = tf.keras.layers.AvgPool1D(pool_size=2)
        self.conv4 = tf.keras.layers.Conv1D(filters=32,
                                            kernel_size=self.kernel_size_1,
                                            activation='relu',
                                            padding= "valid")
        self.spatial_drop_2 = tf.keras.layers.SpatialDropout1D(self.drop_rate)
        self.flat = tf.keras.layers.Flatten()
        self.dense1 = tf.keras.layers.Dense(296, activation='relu')
        self.dropout1 = tf.keras.layers.Dropout(self.drop_rate)
        self.dense2 = tf.keras.layers.Dense(148, activation='relu')
        self.dropout2 = tf.keras.layers.Dropout(self.drop_rate)
        self.dense3 = tf.keras.layers.Dense(74, activation='relu')
        self.dropout3 = tf.keras.layers.Dropout(self.drop_rate)
        self.out = tf.keras.layers.Dense(5, activation='softmax')

    def call(self, input_tensor):
        conv1 = self.conv1(input_tensor)
        conv2 = self.conv2(conv1)
        spatial_drop_1 = self.spatial_drop_1(conv2)
        conv3 = self.conv3(spatial_drop_1)
        avg_pool1 = self.avg_pool1(conv3)
        conv4 = self.conv4(avg_pool1)
        spatial_drop_2 = self.spatial_drop_2(conv4)
        flat = self.flat(spatial_drop_2)
        dense1 = self.dense1(flat)
        dropout1 = self.dropout1(dense1)
        dense2 = self.dense2(dropout1)
        dropout2 = self.dropout2(dense2)
        return self.out(dropout2)

if __name__ == '__main__':
    # path = "YOUR MODEL PATH"
    # model = tf.keras.models.load_model(path, custom_objects={"CustomModel": HopefullNet})
    model=HopefullNet()
    model.build(input_shape=(None, 300, 2))
    model.call(tf.keras.Input(shape=(300,2)))
    model.summary()