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
        self.assertEqual(
            {a.filename: md5(a.read()).hexdigest() for a in ar}, {
            'archive/__init__.py': '29a6a1e050bd42fe24cd17b138d4b08d',
            'archive/core.pyx': '1bd9e27890beb0b576a2122e7b57ca8c',
            'setup.py': 'de88961c0eca3d7875894eae7d551d18',
            })

    def testIncremental(self):
        ar = archive.Archive('test.tgz')
        for ent in ar:
            if ent.filename == 'setup.py':
                break
        else:
            raise AssertionError("No setup.py")
        buf = b""
        while True:
            chunk = ent.read(100)
            if not chunk:
                break
            buf += chunk
        self.assertEqual(md5(buf).hexdigest(),
            'de88961c0eca3d7875894eae7d551d18')

if __name__ == '__main__':
    unittest.main()

