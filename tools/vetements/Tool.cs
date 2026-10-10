using System;
using System.IO;
using System.Xml;
using CodeWalker.GameFiles;
class Tool {
    static int Main(string[] a) {
        if (a[0] == "ymt2xml") {
            var y = new YmtFile(); y.Load(File.ReadAllBytes(a[1]));
            string fn; File.WriteAllText(a[2], MetaXml.GetXml(y, out fn)); return 0;
        }
        if (a[0] == "xml2ymt") {
            var d = new XmlDocument(); d.Load(a[1]);
            var data = XmlMeta.GetData(d, MetaFormat.RSC, a[1]);
            if (data == null) { Console.Error.WriteLine("echec"); return 1; }
            File.WriteAllBytes(a[2], data); return 0;
        }
        return 2;
    }
}
