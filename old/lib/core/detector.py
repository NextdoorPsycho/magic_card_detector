"""
Core detector class for MTG card detector.
"""

import glob
import os
import pickle
import cv2

from lib.models import ReferenceImage, TestImage
from lib.image import segment_image
from lib.core.recognition import phash_compare


class MagicCardDetector:
    """
    MTG card detector class.
    """
    def __init__(self, output_path=None):
        """
        Initialize the detector.
        output_path: Optional path for saving results.
        """
        self.output_path = output_path
        self.reference_images = []
        self.test_images = []

        self.verbose = False
        self.visual = False

        self.hash_separation_thr = 4.0
        self.thr_lvl = 70

        self.clahe = cv2.createCLAHE(clipLimit=2.0,
                                    tileGridSize=(8, 8))

    def export_reference_data(self, path):
        """
        Exports the phash and card name of the reference data list.
        """
        hlist = []
        for image in self.reference_images:
            hlist.append(ReferenceImage(image.name,
                                       None,
                                       None,
                                       image.phash))

        with open(path, 'wb') as fhandle:
            pickle.dump(hlist, fhandle)

    def read_prehashed_reference_data(self, path):
        """
        Reads pre-calculated hashes of the reference images.
        """
        print('Reading prehashed data from ' + str(path))
        print('...', end=' ')
        with open(path, 'rb') as filename:
            hashed_list = pickle.load(filename)
        for ref_im in hashed_list:
            self.reference_images.append(
                ReferenceImage(ref_im.name, None, self.clahe, ref_im.phash))
        print('Done.')

    def read_and_adjust_reference_images(self, path):
        """
        Reads and histogram-adjusts the reference image set.
        Pre-calculates the hashes of the images.
        """
        print('Reading images from ' + str(path))
        print('...', end=' ')
        filenames = glob.glob(path + '*.jpg')
        for filename in filenames:
            img = cv2.imread(filename)
            img_name = filename.split(path)[1]
            self.reference_images.append(
                ReferenceImage(img_name, img, self.clahe))
        print('Done.')

    def read_and_adjust_test_images(self, path):
        """
        Reads and histogram-adjusts the test image set.
        """
        maxsize = 1000
        print('Reading images from ' + str(path))
        print('...', end=' ')
        filenames = glob.glob(path.rstrip('/') + '/*.jpg')
        for filename in filenames:
            img = cv2.imread(filename)
            if min(img.shape[0], img.shape[1]) > maxsize:
                scalef = maxsize / min(img.shape[0], img.shape[1])
                img = cv2.resize(img,
                                (int(img.shape[1] * scalef),
                                 int(img.shape[0] * scalef)),
                                interpolation=cv2.INTER_AREA)

            img_name = os.path.basename(filename)
            self.test_images.append(
                TestImage(img_name, img, self.clahe))
        print('Done.')

    def recognize_segment(self, image_segment):
        """
        Wrapper for different segmented image recognition algorithms.
        """
        return phash_compare(image_segment, self.reference_images, 
                           self.hash_separation_thr, self.verbose)

    def recognize_cards_in_image(self, test_image, contouring_mode):
        """
        Tries to recognize cards from the image specified.
        The image has been read in and adjusted previously,
        and is contained in the internal data list of the class.
        """
        print('Segmentating card candidates out of the image...')
        print('Using ' + str(contouring_mode) + ' algorithm.')

        test_image.candidate_list.clear()
        segment_image(test_image, contouring_mode=contouring_mode, 
                    visual=self.visual, verbose=self.verbose)

        print('Done. Found ' +
              str(len(test_image.candidate_list)) + ' candidates.')
        print('Recognizing candidates.')

        for i_cand, candidate in enumerate(test_image.candidate_list):
            im_seg = candidate.image
            if self.verbose:
                print(str(i_cand + 1) + " / " +
                      str(len(test_image.candidate_list)))

            # Easy fragment / duplicate detection
            for other_candidate in test_image.candidate_list:
                if (other_candidate.is_recognized and
                        not other_candidate.is_fragment):
                    if other_candidate.contains(candidate):
                        candidate.is_fragment = True
            if not candidate.is_fragment:
                (candidate.is_recognized,
                 candidate.recognition_score,
                 candidate.name) = self.recognize_segment(im_seg)

        print('Done. Found ' +
              str(len(test_image.return_recognized())) +
              ' cards.')
        if self.verbose:
            for card in test_image.return_recognized():
                print(card.name + '; S = ' + str(card.recognition_score))
        print('Removing duplicates...')
        # Final fragment detection
        test_image.mark_fragments()
        print('Done.')

    def run_recognition(self, image_index=None):
        """
        The top-level image recognition method.
        Wrapper for switching to different algorithms and re-trying.
        """
        if image_index is None:
            image_index = range(len(self.test_images))
        elif not isinstance(image_index, list):
            image_index = [image_index]
        for i in image_index:
            test_image = self.test_images[i]
            print('Accessing image ' + test_image.name)

            if self.visual:
                import matplotlib.pyplot as plt
                print('Original image')
                plt.imshow(cv2.cvtColor(test_image.original,
                                       cv2.COLOR_BGR2RGB))
                plt.show()

            alg_list = ['adaptive', 'rgb']

            for alg in alg_list:
                self.recognize_cards_in_image(test_image, alg)
                test_image.discard_unrecognized_candidates()
                if (not test_image.may_contain_more_cards() or
                        len(test_image.return_recognized()) > 5):
                    break

            print('Plotting and saving the results...')
            test_image.plot_image_with_recognized(self.output_path, self.visual)
            print('Done.')
            test_image.print_recognized()
        print('Recognition done.')