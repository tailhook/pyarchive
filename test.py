import unittest
from hashlib import md5

class Test(unittest.TestCase):

    def setUp(self):
        import archive
        global archive

    def testNames(self):
        ar = archive.Archive('test.tgz')
        self.assertSetEqual(set(a.filename for a in ar), set([
            'archive/__init__.py',
            'archive/core.pyx',
            'setup.py',
            ]))

    def testData(self):
        ar = archive.Archive('test.tgz')
        self.assertEqual({a.filename: md5(a.read(4096)).hexdigest() for a in ar}, {
            'archive/__init__.py': '29a6a1e050bd42fe24cd17b138d4b08d',
            'archive/core.pyx': '567f171c01faf23b124ab23283b149a9',
            'setup.py': 'de88961c0eca3d7875894eae7d551d18',
            })

if __name__ == '__main__':
    unittest.main()

