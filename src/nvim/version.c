/// @file version.c
///
/// Nvim was forked from Vim 7.4.160.
/// Vim originated from Stevie version 3.6 (Fish disk 217) by GRWalter (Fred).

#include <assert.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "auto/versiondef.h"  // version info generated by the build system
#include "auto/versiondef_git.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/drawscreen.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/lua/executor.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option_vars.h"
#include "nvim/os/os.h"
#include "nvim/strings.h"
#include "nvim/version.h"

// for ":version", ":intro", and "nvim --version"
#ifndef NVIM_VERSION_MEDIUM
# define NVIM_VERSION_MEDIUM "v" STR(NVIM_VERSION_MAJOR) \
  "." STR(NVIM_VERSION_MINOR) "." STR(NVIM_VERSION_PATCH) \
  NVIM_VERSION_PRERELEASE
#endif
#define NVIM_VERSION_LONG "NVIM " NVIM_VERSION_MEDIUM  // NOLINT(bugprone-suspicious-missing-comma)

char *Version = VIM_VERSION_SHORT;
char *longVersion = NVIM_VERSION_LONG;
char *version_buildtype = "Build type: " NVIM_VERSION_BUILD_TYPE;
// Reproducible builds: omit compile info in Release builds. #15424
#ifndef NDEBUG
char *version_cflags = "Compilation: " NVIM_VERSION_CFLAGS;
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "version.c.generated.h"
#endif

// clang-format off
static const int included_patches[] = {
  2424,
  2423,
  2422,
  2421,
  // 2420,
  2419,
  // 2418,
  2417,
  2416,
  // 2415,
  2414,
  2413,
  2412,
  2411,
  2410,
  2409,
  2408,
  2407,
  2406,
  2405,
  2404,
  2403,
  2402,
  2401,
  2400,
  // 2399,
  2398,
  2397,
  2396,
  2395,
  2394,
  2393,
  2392,
  2391,
  2390,
  2389,
  2388,
  2387,
  // 2386,
  2385,
  2384,
  2383,
  2382,
  // 2381,
  2380,
  2379,
  2378,
  2377,
  2376,
  2375,
  2374,
  2373,
  2372,
  // 2371,
  2370,
  // 2369,
  2368,
  2367,
  2366,
  2365,
  2364,
  2363,
  // 2362,
  2361,
  2360,
  2359,
  2358,
  2357,
  2356,
  2355,
  2354,
  2353,
  2352,
  // 2351,
  2350,
  2349,
  2348,
  2347,
  2346,
  2345,
  2344,
  2343,
  2342,
  2341,
  2340,
  2339,
  2338,
  // 2337,
  2336,
  2335,
  // 2334,
  2333,
  2332,
  2331,
  2330,
  2329,
  2328,
  2327,
  2326,
  2325,
  // 2324,
  2323,
  2322,
  2321,
  2320,
  2319,
  2318,
  2317,
  2316,
  2315,
  2314,
  2313,
  2312,
  2311,
  2310,
  2309,
  // 2308,
  // 2307,
  2306,
  2305,
  2304,
  2303,
  2302,
  2301,
  // 2300,
  // 2299,
  // 2298,
  2297,
  // 2296,
  // 2295,
  2294,
  2293,
  // 2292,
  2291,
  2290,
  2289,
  // 2288,
  // 2287,
  // 2286,
  2285,
  2284,
  2283,
  2282,
  2281,
  2280,
  // 2279,
  2278,
  // 2277,
  2276,
  2275,
  2274,
  // 2273,
  2272,
  2271,
  2270,
  2269,
  2268,
  2267,
  // 2266,
  // 2265,
  2264,
  2263,
  2262,
  2261,
  2260,
  2259,
  2258,
  2257,
  2256,
  2255,
  2254,
  2253,
  2252,
  // 2251,
  // 2250,
  2249,
  2248,
  2247,
  2246,
  2245,
  2244,
  2243,
  2242,
  // 2241,
  // 2240,
  2239,
  2238,
  2237,
  2236,
  2235,
  2234,
  2233,
  // 2232,
  2231,
  // 2230,
  2229,
  2228,
  2227,
  2226,
  2225,
  2224,
  2223,
  2222,
  2221,
  2220,
  // 2219,
  2218,
  2217,
  // 2216,
  // 2215,
  2214,
  // 2213,
  2212,
  // 2211,
  // 2210,
  2209,
  // 2208,
  2207,
  2206,
  2205,
  2204,
  2203,
  2202,
  2201,
  // 2200,
  2199,
  2198,
  2197,
  2196,
  // 2195,
  // 2194,
  // 2193,
  // 2192,
  2191,
  2190,
  // 2189,
  2188,
  2187,
  2186,
  2185,
  2184,
  2183,
  2182,
  // 2181,
  2180,
  2179,
  2178,
  2177,
  // 2176,
  2175,
  2174,
  2173,
  2172,
  2171,
  2170,
  2169,
  2168,
  2167,
  2166,
  2165,
  // 2164,
  2163,
  2162,
  2161,
  2160,
  2159,
  // 2158,
  2157,
  // 2156,
  // 2155,
  2154,
  // 2153,
  2152,
  2151,
  2150,
  2149,
  2148,
  2147,
  // 2146,
  2145,
  2144,
  2143,
  // 2142,
  2141,
  2140,
  // 2139,
  2138,
  2137,
  2136,
  2135,
  2134,
  2133,
  2132,
  2131,
  2130,
  2129,
  2128,
  // 2127,
  2126,
  2125,
  2124,
  2123,
  2122,
  // 2121,
  2120,
  2119,
  2118,
  2117,
  2116,
  2115,
  // 2114,
  2113,
  2112,
  2111,
  // 2110,
  // 2109,
  2108,
  // 2107,
  2106,
  2105,
  2104,
  2103,
  2102,
  2101,
  2100,
  2099,
  2098,
  2097,
  2096,
  2095,
  2094,
  // 2093,
  // 2092,
  2091,
  2090,
  2089,
  2088,
  2087,
  2086,
  // 2085,
  2084,
  2083,
  2082,
  2081,
  // 2080,
  2079,
  2078,
  // 2077,
  // 2076,
  2075,
  2074,
  2073,
  2072,
  // 2071,
  2070,
  2069,
  2068,
  2067,
  2066,
  2065,
  2064,
  2063,
  2062,
  2061,
  2060,
  2059,
  2058,
  2057,
  2056,
  2055,
  2054,
  2053,
  2052,
  2051,
  2050,
  2049,
  2048,
  2047,
  2046,
  2045,
  2044,
  2043,
  2042,
  2041,
  // 2040,
  // 2039,
  2038,
  2037,
  2036,
  2035,
  2034,
  2033,
  // 2032,
  2031,
  2030,
  2029,
  2028,
  2027,
  2026,
  2025,
  2024,
  2023,
  // 2022,
  // 2021,
  2020,
  2019,
  2018,
  2017,
  2016,
  2015,
  2014,
  2013,
  2012,
  2011,
  2010,
  // 2009,
  // 2008,
  2007,
  2006,
  2005,
  // 2004,
  2003,
  2002,
  2001,
  2000,
  // 1999,
  // 1998,
  // 1997,
  // 1996,
  1995,
  1994,
  // 1993,
  1992,
  1991,
  1990,
  // 1989,
  1988,
  // 1987,
  // 1986,
  // 1985,
  1984,
  1983,
  // 1982,
  // 1981,
  1980,
  // 1979,
  // 1978,
  1977,
  1976,
  1975,
  1974,
  1973,
  1972,
  1971,
  1970,
  // 1969,
  1968,
  1967,
  1966,
  1965,
  // 1964,
  // 1963,
  1962,
  1961,
  1960,
  // 1959,
  1958,
  // 1957,
  1956,
  1955,
  // 1954,
  1953,
  1952,
  1951,
  1950,
  1949,
  1948,
  1947,
  1946,
  // 1945,
  // 1944,
  // 1943,
  1942,
  1941,
  // 1940,
  // 1939,
  1938,
  1937,
  // 1936,
  1935,
  // 1934,
  1933,
  1932,
  1931,
  1930,
  // 1929,
  // 1928,
  1927,
  1926,
  1925,
  1924,
  1923,
  1922,
  1921,
  // 1920,
  // 1919,
  // 1918,
  // 1917,
  1916,
  1915,
  1914,
  1913,
  1912,
  1911,
  1910,
  1909,
  // 1908,
  // 1907,
  // 1906,
  // 1905,
  // 1904,
  1903,
  // 1902,
  1901,
  1900,
  1899,
  1898,
  1897,
  1896,
  1895,
  1894,
  1893,
  // 1892,
  // 1891,
  1890,
  1889,
  1888,
  1887,
  1886,
  1885,
  // 1884,
  1883,
  // 1882,
  1881,
  // 1880,
  1879,
  1878,
  1877,
  1876,
  1875,
  // 1874,
  1873,
  1872,
  // 1871,
  1870,
  1869,
  1868,
  1867,
  // 1866,
  1865,
  1864,
  1863,
  1862,
  1861,
  1860,
  1859,
  1858,
  1857,
  1856,
  1855,
  1854,
  // 1853,
  1852,
  // 1851,
  // 1850,
  1849,
  1848,
  1847,
  1846,
  // 1845,
  // 1844,
  1843,
  1842,
  1841,
  1840,
  1839,
  1838,
  1837,
  1836,
  1835,
  1834,
  1833,
  1832,
  1831,
  1830,
  1829,
  1828,
  1827,
  1826,
  1825,
  1824,
  1823,
  1822,
  1821,
  1820,
  // 1819,
  1818,
  1817,
  1816,
  1815,
  // 1814,
  // 1813,
  1812,
  // 1811,
  // 1810,
  1809,
  1808,
  1807,
  1806,
  1805,
  1804,
  1803,
  // 1802,
  1801,
  1800,
  // 1799,
  1798,
  1797,
  1796,
  1795,
  1794,
  1793,
  1792,
  1791,
  1790,
  // 1789,
  1788,
  // 1787,
  // 1786,
  1785,
  // 1784,
  1783,
  1782,
  1781,
  1780,
  // 1779,
  // 1778,
  1777,
  1776,
  1775,
  1774,
  // 1773,
  1772,
  1771,
  // 1770,
  1769,
  // 1768,
  1767,
  1766,
  1765,
  1764,
  1763,
  1762,
  1761,
  1760,
  1759,
  1758,
  1757,
  1756,
  // 1755,
  // 1754,
  // 1753,
  // 1752,
  // 1751,
  1750,
  1749,
  1748,
  1747,
  1746,
  1745,
  1744,
  1743,
  1742,
  1741,
  1740,
  1739,
  1738,
  1737,
  // 1736,
  1735,
  1734,
  // 1733,
  1732,
  1731,
  // 1730,
  1729,
  // 1728,
  1727,
  1726,
  1725,
  1724,
  1723,
  1722,
  1721,
  1720,
  // 1719,
  // 1718,
  1717,
  1716,
  1715,
  // 1714,
  // 1713,
  1712,
  // 1711,
  // 1710,
  // 1709,
  1708,
  // 1707,
  1706,
  1705,
  1704,
  // 1703,
  1702,
  1701,
  // 1700,
  1699,
  1698,
  1697,
  1696,
  1695,
  1694,
  1693,
  1692,
  1691,
  // 1690,
  1689,
  1688,
  1687,
  1686,
  1685,
  1684,
  1683,
  1682,
  // 1681,
  1680,
  1679,
  // 1678,
  1677,
  // 1676,
  // 1675,
  1674,
  // 1673,
  1672,
  1671,
  1670,
  1669,
  1668,
  1667,
  // 1666,
  // 1665,
  1664,
  // 1663,
  1662,
  1661,
  1660,
  // 1659,
  1658,
  1657,
  // 1656,
  // 1655,
  1654,
  1653,
  1652,
  1651,
  1650,
  // 1649,
  1648,
  1647,
  // 1646,
  1645,
  1644,
  1643,
  1642,
  // 1641,
  1640,
  1639,
  1638,
  1637,
  // 1636,
  1635,
  1634,
  1633,
  1632,
  1631,
  1630,
  // 1629,
  // 1628,
  1627,
  // 1626,
  1625,
  1624,
  1623,
  // 1622,
  1621,
  // 1620,
  1619,
  1618,
  // 1617,
  1616,
  // 1615,
  1614,
  1613,
  // 1612,
  1611,
  1610,
  // 1609,
  1608,
  // 1607,
  1606,
  1605,
  1604,
  // 1603,
  // 1602,
  1601,
  // 1600,
  // 1599,
  1598,
  // 1597,
  // 1596,
  1595,
  1594,
  1593,
  1592,
  1591,
  1590,
  // 1589,
  1588,
  1587,
  // 1586,
  1585,
  // 1584,
  1583,
  1582,
  1581,
  // 1580,
  1579,
  1578,
  // 1577,
  1576,
  1575,
  // 1574,
  // 1573,
  1572,
  // 1571,
  1570,
  1569,
  1568,
  1567,
  1566,
  // 1565,
  1564,
  1563,
  // 1562,
  // 1561,
  // 1560,
  // 1559,
  // 1558,
  1557,
  1556,
  // 1555,
  1554,
  // 1553,
  1552,
  // 1551,
  // 1550,
  1549,
  // 1548,
  1547,
  1546,
  1545,
  1544,
  1543,
  1542,
  1541,
  1540,
  1539,
  // 1538,
  // 1537,
  1536,
  1535,
  // 1534,
  1533,
  1532,
  1531,
  1530,
  1529,
  1528,
  // 1527,
  // 1526,
  // 1525,
  1524,
  // 1523,
  1522,
  1521,
  1520,
  1519,
  1518,
  1517,
  1516,
  1515,
  1514,
  1513,
  1512,
  1511,
  1510,
  1509,
  1508,
  1507,
  1506,
  1505,
  1504,
  1503,
  1502,
  1501,
  1500,
  1499,
  1498,
  1497,
  1496,
  1495,
  1494,
  1493,
  1492,
  1491,
  1490,
  1489,
  1488,
  1487,
  1486,
  1485,
  1484,
  1483,
  1482,
  1481,
  1480,
  1479,
  1478,
  1477,
  1476,
  1475,
  1474,
  // 1473,
  1472,
  1471,
  1470,
  1469,
  1468,
  1467,
  1466,
  1465,
  1464,
  1463,
  1462,
  1461,
  1460,
  1459,
  1458,
  1457,
  1456,
  1455,
  1454,
  1453,
  1452,
  1451,
  1450,
  1449,
  1448,
  1447,
  1446,
  1445,
  1444,
  1443,
  1442,
  1441,
  1440,
  1439,
  1438,
  1437,
  1436,
  1435,
  1434,
  1433,
  1432,
  1431,
  1430,
  1429,
  1428,
  1427,
  1426,
  1425,
  1424,
  1423,
  1422,
  1421,
  1420,
  1419,
  1418,
  // 1417,
  1416,
  1415,
  1414,
  // 1413,
  1412,
  1411,
  1410,
  1409,
  1408,
  1407,
  1406,
  1405,
  1404,
  1403,
  1402,
  1401,
  1400,
  1399,
  1398,
  1397,
  1396,
  // 1395,
  1394,
  1393,
  1392,
  1391,
  1390,
  // 1389,
  1388,
  1387,
  1386,
  1385,
  1384,
  1383,
  1382,
  1381,
  1380,
  1379,
  1378,
  1377,
  1376,
  1375,
  1374,
  1373,
  1372,
  1371,
  1370,
  1369,
  1368,
  1367,
  1366,
  1365,
  1364,
  1363,
  1362,
  1361,
  1360,
  1359,
  1358,
  1357,
  1356,
  1355,
  1354,
  1353,
  1352,
  1351,
  1350,
  1349,
  1348,
  1347,
  1346,
  1345,
  1344,
  1343,
  1342,
  1341,
  1340,
  1339,
  1338,
  1337,
  1336,
  1335,
  1334,
  1333,
  1332,
  1331,
  1330,
  1329,
  1328,
  1327,
  1326,
  1325,
  1324,
  1323,
  1322,
  1321,
  1320,
  1319,
  1318,
  1317,
  1316,
  1315,
  1314,
  1313,
  1312,
  1311,
  1310,
  1309,
  1308,
  1307,
  1306,
  1305,
  1304,
  1303,
  1302,
  1301,
  1300,
  1299,
  1298,
  1297,
  1296,
  1295,
  1294,
  1293,
  1292,
  1291,
  1290,
  1289,
  1288,
  1287,
  1286,
  1285,
  1284,
  1283,
  1282,
  1281,
  1280,
  1279,
  1278,
  1277,
  1276,
  1275,
  1274,
  1273,
  1272,
  1271,
  1270,
  1269,
  1268,
  1267,
  1266,
  1265,
  1264,
  1263,
  1262,
  1261,
  1260,
  // 1259,
  1258,
  1257,
  1256,
  1255,
  1254,
  1253,
  1252,
  1251,
  1250,
  1249,
  1248,
  1247,
  1246,
  1245,
  1244,
  1243,
  1242,
  1241,
  1240,
  1239,
  1238,
  1237,
  1236,
  1235,
  1234,
  1233,
  1232,
  1231,
  1230,
  1229,
  1228,
  1227,
  1226,
  1225,
  // 1224,
  1223,
  1222,
  1221,
  1220,
  1219,
  // 1218,
  1217,
  1216,
  1215,
  1214,
  1213,
  1212,
  1211,
  1210,
  1209,
  1208,
  1207,
  1206,
  1205,
  1204,
  1203,
  1202,
  1201,
  1200,
  1199,
  1198,
  1197,
  1196,
  1195,
  1194,
  1193,
  1192,
  1191,
  1190,
  1189,
  1188,
  1187,
  1186,
  1185,
  1184,
  1183,
  1182,
  1181,
  1180,
  1179,
  1178,
  1177,
  1176,
  1175,
  1174,
  1173,
  1172,
  1171,
  1170,
  1169,
  1168,
  1167,
  1166,
  1165,
  1164,
  1163,
  1162,
  1161,
  1160,
  1159,
  1158,
  1157,
  1156,
  1155,
  1154,
  1153,
  1152,
  1151,
  1150,
  1149,
  1148,
  1147,
  1146,
  1145,
  1144,
  1143,
  1142,
  1141,
  1140,
  1139,
  1138,
  1137,
  // 1136,
  1135,
  1134,
  1133,
  1132,
  1131,
  1130,
  1129,
  1128,
  1127,
  1126,
  1125,
  1124,
  1123,
  1122,
  1121,
  1120,
  1119,
  1118,
  1117,
  1116,
  1115,
  1114,
  1113,
  1112,
  1111,
  1110,
  1109,
  1108,
  1107,
  // 1106,
  1105,
  1104,
  1103,
  1102,
  1101,
  1100,
  1099,
  1098,
  1097,
  1096,
  1095,
  1094,
  1093,
  1092,
  1091,
  1090,
  1089,
  1088,
  1087,
  1086,
  1085,
  1084,
  // 1083,
  1082,
  1081,
  1080,
  1079,
  1078,
  1077,
  1076,
  1075,
  1074,
  1073,
  1072,
  1071,
  1070,
  1069,
  1068,
  1067,
  1066,
  1065,
  1064,
  1063,
  1062,
  1061,
  1060,
  1059,
  1058,
  1057,
  1056,
  1055,
  1054,
  1053,
  1052,
  1051,
  1050,
  1049,
  1048,
  1047,
  1046,
  1045,
  // 1044,
  // 1043,
  1042,
  1041,
  1040,
  1039,
  1038,
  1037,
  1036,
  1035,
  1034,
  1033,
  1032,
  1031,
  1030,
  1029,
  1028,
  1027,
  1026,
  1025,
  1024,
  1023,
  1022,
  1021,
  1020,
  1019,
  1018,
  1017,
  1016,
  1015,
  1014,
  1013,
  1012,
  1011,
  1010,
  1009,
  1008,
  1007,
  1006,
  1005,
  // 1004,
  1003,
  1002,
  1001,
  1000,
  999,
  998,
  997,
  996,
  995,
  994,
  993,
  992,
  991,
  990,
  989,
  988,
  987,
  986,
  985,
  984,
  983,
  982,
  981,
  980,
  979,
  978,
  // 977,
  976,
  975,
  974,
  973,
  972,
  971,
  970,
  // 969,
  968,
  967,
  966,
  965,
  964,
  963,
  962,
  961,
  960,
  959,
  958,
  957,
  956,
  955,
  954,
  // 953,
  952,
  951,
  950,
  949,
  948,
  947,
  946,
  945,
  944,
  943,
  942,
  941,
  940,
  939,
  938,
  937,
  936,
  935,
  934,
  933,
  932,
  931,
  930,
  929,
  928,
  927,
  926,
  925,
  924,
  923,
  922,
  921,
  920,
  919,
  918,
  917,
  916,
  915,
  // 914,
  913,
  912,
  911,
  910,
  909,
  908,
  907,
  906,
  905,
  904,
  903,
  902,
  901,
  900,
  899,
  898,
  897,
  896,
  895,
  // 894,
  893,
  892,
  891,
  890,
  889,
  888,
  887,
  886,
  885,
  884,
  883,
  882,
  881,
  880,
  879,
  878,
  877,
  // 876,
  875,
  874,
  873,
  872,
  871,
  870,
  869,
  868,
  867,
  866,
  865,
  864,
  // 863,
  862,
  861,
  860,
  859,
  858,
  // 857,
  856,
  855,
  854,
  853,
  852,
  851,
  850,
  849,
  848,
  847,
  846,
  845,
  844,
  843,
  842,
  841,
  840,
  839,
  838,
  837,
  836,
  835,
  834,
  833,
  832,
  831,
  830,
  829,
  828,
  827,
  826,
  825,
  824,
  823,
  822,
  821,
  820,
  819,
  818,
  817,
  816,
  // 815,
  814,
  813,
  812,
  811,
  810,
  809,
  808,
  807,
  806,
  805,
  804,
  803,
  802,
  801,
  800,
  799,
  798,
  797,
  796,
  795,
  794,
  793,
  792,
  791,
  790,
  789,
  788,
  787,
  786,
  785,
  784,
  783,
  782,
  781,
  780,
  779,
  778,
  777,
  776,
  775,
  774,
  773,
  772,
  771,
  // 770,
  769,
  // 768,
  767,
  766,
  765,
  764,
  763,
  762,
  761,
  760,
  759,
  758,
  757,
  756,
  755,
  754,
  753,
  752,
  751,
  750,
  749,
  748,
  747,
  746,
  745,
  744,
  743,
  742,
  741,
  740,
  739,
  738,
  737,
  736,
  735,
  734,
  733,
  732,
  731,
  730,
  729,
  728,
  727,
  726,
  725,
  724,
  723,
  722,
  721,
  720,
  719,
  718,
  717,
  716,
  715,
  714,
  713,
  712,
  711,
  // 710,
  709,
  708,
  707,
  706,
  705,
  704,
  703,
  702,
  701,
  700,
  699,
  698,
  697,
  696,
  695,
  694,
  693,
  692,
  691,
  690,
  689,
  688,
  687,
  686,
  685,
  684,
  683,
  682,
  681,
  680,
  679,
  678,
  677,
  676,
  675,
  674,
  673,
  672,
  671,
  670,
  669,
  668,
  667,
  666,
  665,
  664,
  663,
  662,
  661,
  660,
  659,
  658,
  657,
  656,
  655,
  654,
  653,
  652,
  651,
  650,
  649,
  648,
  647,
  646,
  645,
  644,
  643,
  642,
  641,
  640,
  639,
  638,
  637,
  // 636,
  635,
  634,
  633,
  632,
  631,
  630,
  629,
  628,
  627,
  626,
  625,
  624,
  623,
  622,
  621,
  620,
  619,
  618,
  617,
  616,
  615,
  614,
  613,
  612,
  611,
  610,
  609,
  608,
  607,
  606,
  605,
  604,
  603,
  602,
  601,
  600,
  599,
  598,
  597,
  596,
  595,
  594,
  593,
  592,
  591,
  590,
  589,
  588,
  587,
  586,
  585,
  584,
  583,
  582,
  581,
  580,
  579,
  578,
  577,
  576,
  575,
  574,
  573,
  572,
  571,
  570,
  569,
  568,
  567,
  566,
  565,
  564,
  563,
  562,
  561,
  560,
  559,
  558,
  557,
  556,
  555,
  554,
  553,
  552,
  551,
  550,
  549,
  548,
  547,
  546,
  545,
  544,
  543,
  542,
  541,
  540,
  539,
  538,
  537,
  536,
  535,
  534,
  533,
  532,
  531,
  530,
  529,
  528,
  527,
  526,
  525,
  524,
  523,
  522,
  521,
  520,
  519,
  518,
  517,
  516,
  515,
  514,
  513,
  512,
  511,
  510,
  509,
  508,
  507,
  506,
  505,
  504,
  503,
  502,
  501,
  500,
  499,
  498,
  497,
  496,
  495,
  494,
  493,
  492,
  491,
  490,
  489,
  488,
  487,
  486,
  485,
  484,
  483,
  482,
  481,
  480,
  479,
  478,
  477,
  476,
  475,
  474,
  473,
  472,
  471,
  470,
  469,
  468,
  467,
  466,
  465,
  464,
  463,
  462,
  461,
  460,
  459,
  458,
  457,
  456,
  455,
  454,
  453,
  452,
  451,
  450,
  449,
  448,
  447,
  446,
  445,
  444,
  443,
  442,
  441,
  440,
  439,
  438,
  437,
  436,
  435,
  434,
  433,
  432,
  431,
  430,
  429,
  428,
  427,
  426,
  // 425,
  424,
  423,
  422,
  421,
  420,
  419,
  418,
  417,
  416,
  415,
  414,
  413,
  412,
  411,
  410,
  409,
  408,
  407,
  406,
  405,
  404,
  403,
  402,
  401,
  400,
  399,
  398,
  397,
  396,
  395,
  394,
  393,
  392,
  391,
  390,
  389,
  388,
  387,
  386,
  385,
  384,
  383,
  382,
  381,
  380,
  379,
  378,
  377,
  376,
  375,
  374,
  373,
  372,
  371,
  370,
  369,
  368,
  367,
  366,
  365,
  364,
  363,
  362,
  361,
  360,
  359,
  358,
  357,
  356,
  355,
  354,
  353,
  352,
  351,
  350,
  349,
  348,
  347,
  346,
  345,
  344,
  343,
  342,
  341,
  340,
  339,
  338,
  337,
  336,
  335,
  334,
  333,
  332,
  331,
  330,
  329,
  // 328,
  327,
  326,
  325,
  324,
  323,
  322,
  321,
  320,
  319,
  318,
  317,
  316,
  315,
  314,
  313,
  312,
  311,
  310,
  309,
  308,
  307,
  306,
  305,
  304,
  303,
  302,
  301,
  300,
  299,
  298,
  297,
  296,
  295,
  294,
  293,
  292,
  291,
  290,
  289,
  288,
  287,
  286,
  285,
  284,
  283,
  282,
  281,
  280,
  279,
  278,
  277,
  276,
  275,
  274,
  273,
  272,
  271,
  270,
  269,
  268,
  267,
  266,
  265,
  264,
  263,
  262,
  261,
  260,
  259,
  258,
  257,
  256,
  255,
  254,
  253,
  252,
  251,
  250,
  249,
  248,
  247,
  246,
  245,
  244,
  243,
  242,
  241,
  240,
  239,
  238,
  237,
  236,
  235,
  234,
  233,
  232,
  231,
  230,
  229,
  228,
  227,
  226,
  225,
  224,
  223,
  222,
  221,
  220,
  219,
  218,
  217,
  216,
  215,
  214,
  213,
  212,
  211,
  210,
  209,
  208,
  207,
  206,
  205,
  204,
  203,
  202,
  201,
  200,
  199,
  198,
  197,
  196,
  195,
  194,
  193,
  192,
  191,
  190,
  189,
  188,
  187,
  186,
  185,
  184,
  183,
  182,
  181,
  180,
  179,
  178,
  177,
  176,
  175,
  174,
  173,
  172,
  171,
  170,
  169,
  168,
  167,
  166,
  165,
  164,
  163,
  162,
  161,
  160,
  159,
  // 158,
  157,
  156,
  155,
  154,
  153,
  152,
  151,
  150,
  149,
  148,
  147,
  146,
  145,
  144,
  143,
  142,
  141,
  140,
  139,
  138,
  137,
  136,
  135,
  134,
  133,
  132,
  131,
  130,
  129,
  128,
  127,
  126,
  125,
  124,
  123,
  122,
  121,
  120,
  119,
  118,
  117,
  116,
  115,
  114,
  113,
  112,
  111,
  110,
  109,
  108,
  107,
  106,
  105,
  104,
  103,
  102,
  101,
  100,
  99,
  98,
  97,
  96,
  95,
  94,
  93,
  92,
  91,
  90,
  89,
  88,
  // 87,
  86,
  85,
  84,
  83,
  82,
  81,
  80,
  79,
  78,
  77,
  76,
  75,
  74,
  73,
  72,
  71,
  70,
  69,
  68,
  67,
  66,
  // 65,
  64,
  63,
  62,
  61,
  60,
  59,
  // 58,
  57,
  56,
  55,
  54,
  53,
  52,
  51,
  50,
  49,
  48,
  47,
  46,
  45,
  44,
  43,
  42,
  41,
  40,
  39,
  38,
  37,
  36,
  35,
  34,
  33,
  32,
  31,
  30,
  29,
  28,
  27,
  26,
  25,
  24,
  23,
  22,
  21,
  20,
  19,
  18,
  17,
  16,
  15,
  14,
  13,
  12,
  11,
  10,
  9,
  8,
  7,
  6,
  5,
  4,
  3,
  2,
  1,
  // 0,
};
// clang-format on

/// Compares a version string to the current Nvim version.
///
/// @param version Version string like "1.3.42"
///
/// @return true if Nvim is at or above the version.
bool has_nvim_version(const char *const version_str)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  const char *p = version_str;
  int minor = 0;
  int patch = 0;

  if (!ascii_isdigit(*p)) {
    return false;
  }
  int major = atoi(p);
  p = strchr(p, '.');  // Find the next dot.

  if (p) {
    p++;  // Advance past the dot.
    if (!ascii_isdigit(*p)) {
      return false;
    }
    minor = atoi(p);
    p = strchr(p, '.');
    if (p) {
      p++;
      if (!ascii_isdigit(*p)) {
        return false;
      }
      patch = atoi(p);
    }
  }

  return (major < NVIM_VERSION_MAJOR
          || (major == NVIM_VERSION_MAJOR
              && (minor < NVIM_VERSION_MINOR
                  || (minor == NVIM_VERSION_MINOR
                      && patch <= NVIM_VERSION_PATCH))));
}

/// Checks whether a Vim patch has been included.
///
/// @param n Patch number.
///
/// @return true if patch `n` has been included.
bool has_vim_patch(int n)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  // Perform a binary search.
  int l = 0;
  int h = (int)(ARRAY_SIZE(included_patches)) - 1;
  while (l < h) {
    const int m = (l + h) / 2;
    if (included_patches[m] == n) {
      return true;
    }
    if (included_patches[m] < n) {
      h = m;
    } else {
      l = m + 1;
    }
  }
  return false;
}

Dictionary version_dict(void)
{
  Dictionary d = ARRAY_DICT_INIT;
  PUT(d, "major", INTEGER_OBJ(NVIM_VERSION_MAJOR));
  PUT(d, "minor", INTEGER_OBJ(NVIM_VERSION_MINOR));
  PUT(d, "patch", INTEGER_OBJ(NVIM_VERSION_PATCH));
#ifndef NVIM_VERSION_BUILD
  PUT(d, "build", NIL);
#else
  PUT(d, "build", CSTR_AS_OBJ(NVIM_VERSION_BUILD));
#endif
  PUT(d, "prerelease", BOOLEAN_OBJ(NVIM_VERSION_PRERELEASE[0] != '\0'));
  PUT(d, "api_level", INTEGER_OBJ(NVIM_API_LEVEL));
  PUT(d, "api_compatible", INTEGER_OBJ(NVIM_API_LEVEL_COMPAT));
  PUT(d, "api_prerelease", BOOLEAN_OBJ(NVIM_API_PRERELEASE));
  return d;
}

void ex_version(exarg_T *eap)
{
  // Ignore a ":version 9.99" command.
  if (*eap->arg == NUL) {
    msg_putchar('\n');
    list_version();
  }
}

/// Output a string for the version message.  If it's going to wrap, output a
/// newline, unless the message is too long to fit on the screen anyway.
/// When "wrap" is true wrap the string in [].
/// @param s
/// @param wrap
static void version_msg_wrap(char *s, bool wrap)
{
  int len = vim_strsize(s) + (wrap ? 2 : 0);

  if (!got_int
      && (len < Columns)
      && (msg_col + len >= Columns)
      && (*s != '\n')) {
    msg_putchar('\n');
  }

  if (!got_int) {
    if (wrap) {
      msg_puts("[");
    }
    msg_puts(s);
    if (wrap) {
      msg_puts("]");
    }
  }
}

static void version_msg(char *s)
{
  version_msg_wrap(s, false);
}

/// List string items nicely aligned in columns.
/// When "size" is < 0 then the last entry is marked with NULL.
/// The entry with index "current" is inclosed in [].
void list_in_columns(char **items, int size, int current)
{
  int item_count = 0;
  int width = 0;

  // Find the length of the longest item, use that + 1 as the column width.
  for (int i = 0; size < 0 ? items[i] != NULL : i < size; i++) {
    int l = vim_strsize(items[i]) + (i == current ? 2 : 0);

    if (l > width) {
      width = l;
    }
    item_count++;
  }
  width += 1;

  if (Columns < width) {
    // Not enough screen columns - show one per line
    for (int i = 0; i < item_count; i++) {
      version_msg_wrap(items[i], i == current);
      if (msg_col > 0 && i < item_count - 1) {
        msg_putchar('\n');
      }
    }
    return;
  }

  // The rightmost column doesn't need a separator.
  // Sacrifice it to fit in one more column if possible.
  int ncol = (Columns + 1) / width;
  int nrow = item_count / ncol + (item_count % ncol ? 1 : 0);
  int cur_row = 1;

  // "i" counts columns then rows.  "idx" counts rows then columns.
  for (int i = 0; !got_int && i < nrow * ncol; i++) {
    int idx = (i / ncol) + (i % ncol) * nrow;
    if (idx < item_count) {
      bool last_col = (i + 1) % ncol == 0;
      if (idx == current) {
        msg_putchar('[');
      }
      msg_puts(items[idx]);
      if (idx == current) {
        msg_putchar(']');
      }
      if (last_col) {
        if (msg_col > 0 && cur_row < nrow) {
          msg_putchar('\n');
        }
        cur_row++;
      } else {
        while (msg_col % width) {
          msg_putchar(' ');
        }
      }
    } else {
      // this row is out of items, thus at the end of the row
      if (msg_col > 0) {
        if (cur_row < nrow) {
          msg_putchar('\n');
        }
        cur_row++;
      }
    }
  }
}

void list_lua_version(void)
{
  Error err = ERROR_INIT;
  Object ret = NLUA_EXEC_STATIC("return ((jit and jit.version) and jit.version or _VERSION)",
                                (Array)ARRAY_DICT_INIT, kRetObject, NULL, &err);
  assert(!ERROR_SET(&err));
  assert(ret.type == kObjectTypeString);
  msg(ret.data.string.data, 0);
  api_free_object(ret);
}

void list_version(void)
{
  msg(longVersion, 0);
  msg(version_buildtype, 0);
  list_lua_version();

  if (p_verbose > 0) {
#ifndef NDEBUG
    msg(version_cflags, 0);
#endif
    version_msg("\n\n");

#ifdef SYS_VIMRC_FILE
    version_msg(_("   system vimrc file: \""));
    version_msg(SYS_VIMRC_FILE);
    version_msg("\"\n");
#endif

    if (*default_vim_dir != NUL) {
      version_msg(_("  fall-back for $VIM: \""));
      version_msg(default_vim_dir);
      version_msg("\"\n");
    }

    if (*default_vimruntime_dir != NUL) {
      version_msg(_(" f-b for $VIMRUNTIME: \""));
      version_msg(default_vimruntime_dir);
      version_msg("\"\n");
    }
  }

  version_msg(p_verbose > 0
              ? "\nRun :checkhealth for more info"
              : (starting
                 ? "\nRun \"nvim -V1 -v\" for more info"
                 : "\nRun \":verbose version\" for more info"));
}

/// Show the intro message when not editing a file.
void maybe_intro_message(void)
{
  if (buf_is_empty(curbuf)
      && (curbuf->b_fname == NULL)
      && (firstwin->w_next == NULL)
      && (vim_strchr(p_shm, SHM_INTRO) == NULL)) {
    intro_message(false);
  }
}

/// Give an introductory message about Vim.
/// Only used when starting Vim on an empty file, without a file name.
/// Or with the ":intro" command (for Sven :-).
///
/// @param colon true for ":intro"
void intro_message(int colon)
{
  static char *(lines[]) = {
    N_(NVIM_VERSION_LONG),
    "",
    N_("Nvim is open source and freely distributable"),
    "https://neovim.io/#chat",
    "",
    N_("type  :help nvim<Enter>       if you are new! "),
    N_("type  :checkhealth<Enter>     to optimize Nvim"),
    N_("type  :q<Enter>               to exit         "),
    N_("type  :help<Enter>            for help        "),
    "",
    N_("type  :help news<Enter> to see changes in v%s.%s"),
    "",
    N_("Help poor children in Uganda!"),
    N_("type  :help iccf<Enter>       for information "),
  };

  // blanklines = screen height - # message lines
  size_t lines_size = ARRAY_SIZE(lines);
  assert(lines_size <= LONG_MAX);

  int blanklines = Rows - ((int)lines_size - 1);

  // Don't overwrite a statusline.  Depends on 'cmdheight'.
  if (p_ls > 1) {
    blanklines -= Rows - topframe->fr_height;
  }

  if (blanklines < 0) {
    blanklines = 0;
  }

  // Show the sponsor and register message one out of four times, the Uganda
  // message two out of four times.
  int sponsor = (int)time(NULL);
  sponsor = ((sponsor & 2) == 0) - ((sponsor & 4) == 0);

  // start displaying the message lines after half of the blank lines
  int row = blanklines / 2;

  if (((row >= 2) && (Columns >= 50)) || colon) {
    for (int i = 0; i < (int)ARRAY_SIZE(lines); i++) {
      char *p = lines[i];
      char *mesg = NULL;
      int mesg_size = 0;

      if (strstr(p, "news") != NULL) {
        p = _(p);
        mesg_size = snprintf(NULL, 0, p,
                             STR(NVIM_VERSION_MAJOR), STR(NVIM_VERSION_MINOR));
        assert(mesg_size > 0);
        mesg = xmallocz((size_t)mesg_size);
        snprintf(mesg, (size_t)mesg_size + 1, p,
                 STR(NVIM_VERSION_MAJOR), STR(NVIM_VERSION_MINOR));
      } else if (sponsor != 0) {
        if (strstr(p, "children") != NULL) {
          p = sponsor < 0
              ? N_("Sponsor Vim development!")
              : N_("Become a registered Vim user!");
        } else if (strstr(p, "iccf") != NULL) {
          p = sponsor < 0
              ? N_("type  :help sponsor<Enter>    for information ")
              : N_("type  :help register<Enter>   for information ");
        }
      }

      if (mesg == NULL) {
        if (*p != NUL) {
          mesg = _(p);
        } else {
          mesg = "";
        }
      }

      if (*mesg != NUL) {
        do_intro_line(row, mesg, 0);
      }
      row++;

      if (mesg_size > 0) {
        XFREE_CLEAR(mesg);
      }
    }
  }
}

static void do_intro_line(int row, char *mesg, int attr)
{
  int l;

  // Center the message horizontally.
  int col = vim_strsize(mesg);

  col = (Columns - col) / 2;

  if (col < 0) {
    col = 0;
  }

  grid_line_start(&default_grid, row);
  // Split up in parts to highlight <> items differently.
  for (char *p = mesg; *p != NUL; p += l) {
    for (l = 0;
         p[l] != NUL && (l == 0 || (p[l] != '<' && p[l - 1] != '>'));
         l++) {
      l += utfc_ptr2len(p + l) - 1;
    }
    assert(row <= INT_MAX && col <= INT_MAX);
    col += grid_line_puts(col, p, l, *p == '<' ? HL_ATTR(HLF_8) : attr);
  }
  grid_line_flush();
}

/// ":intro": clear screen, display intro screen and wait for return.
///
/// @param eap
void ex_intro(exarg_T *eap)
{
  // TODO(bfredl): use msg_grid instead!
  screenclear();
  intro_message(true);
  wait_return(true);
}
