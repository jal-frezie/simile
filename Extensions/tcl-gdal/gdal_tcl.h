// data types, these are straight copy from gdal.h

typedef char **CSLConstList;
typedef void *GDALDatasetH;
typedef void *GDALDriverH;
typedef void *GDALRasterBandH;
typedef enum
{
    /*! Read only (no update) access */ GA_ReadOnly = 0,
    /*! Read/write access. */ GA_Update = 1
} GDALAccess;
typedef enum
{
    /*! Read data */ GF_Read = 0,
    /*! Write data */ GF_Write = 1
} GDALRWFlag;
typedef enum
{
    CE_None = 0,
    CE_Debug = 1,
    CE_Warning = 2,
    CE_Failure = 3,
    CE_Fatal = 4
} CPLErr;
typedef enum
{
    /*! Unknown or unspecified type */ GDT_Unknown = 0,
    /*! Eight bit unsigned integer */ GDT_Byte = 1,
    /*! 8-bit signed integer (GDAL >= 3.7) */ GDT_Int8 = 14,
    /*! Sixteen bit unsigned integer */ GDT_UInt16 = 2,
    /*! Sixteen bit signed integer */ GDT_Int16 = 3,
    /*! Thirty two bit unsigned integer */ GDT_UInt32 = 4,
    /*! Thirty two bit signed integer */ GDT_Int32 = 5,
    /*! 64 bit unsigned integer (GDAL >= 3.5)*/ GDT_UInt64 = 12,
    /*! 64 bit signed integer  (GDAL >= 3.5)*/ GDT_Int64 = 13,
    /*! Thirty two bit floating point */ GDT_Float32 = 6,
    /*! Sixty four bit floating point */ GDT_Float64 = 7,
    /*! Complex Int16 */ GDT_CInt16 = 8,
    /*! Complex Int32 */ GDT_CInt32 = 9,
    /* TODO?(#6879): GDT_CInt64 */
    /*! Complex Float32 */ GDT_CFloat32 = 10,
    /*! Complex Float64 */ GDT_CFloat64 = 11,
    GDT_TypeCount = 15 /* maximum type # + 1 */
} GDALDataType;

// callback functions
typedef int (*GDALProgressFunc) (double dfComplete,
                                           const char *pszMessage,
                                           void *pProgressArg);

// typedefs for functions
typedef void GDALAllRegister_type(void);
GDALAllRegister_type *GDALAllRegister;
typedef GDALDatasetH GDALOpen_type(const char *pszFilename, GDALAccess eAccess);
GDALOpen_type *GDALOpen;
typedef GDALDriverH GDALGetDriverByName_type(const char *);
GDALGetDriverByName_type *GDALGetDriverByName;
typedef GDALDatasetH GDALCreateCopy_type(GDALDriverH, const char *,
					 GDALDatasetH, int, CSLConstList,
					 GDALProgressFunc,
					 void *);
GDALCreateCopy_type *GDALCreateCopy;
typedef int GDALGetRasterXSize_type(GDALDatasetH);
GDALGetRasterXSize_type *GDALGetRasterXSize;
typedef int GDALGetRasterYSize_type(GDALDatasetH);
GDALGetRasterYSize_type *GDALGetRasterYSize;
typedef int GDALGetRasterCount_type(GDALDatasetH);
GDALGetRasterCount_type *GDALGetRasterCount;
typedef GDALRasterBandH GDALGetRasterBand_type(GDALDatasetH, int);
GDALGetRasterBand_type *GDALGetRasterBand;
typedef CPLErr GDALClose_type(GDALDatasetH);
GDALClose_type *GDALClose;
typedef CPLErr GDALRasterIO_type(GDALRasterBandH hRBand,
		      GDALRWFlag eRWFlag, int nDSXOff,
		      int nDSYOff, int nDSXSize, int nDSYSize,
		      void *pBuffer, int nBXSize, int nBYSize,
		      GDALDataType eBDataType,
		      int nPixelSpace,
		      int nLineSpace);
GDALRasterIO_type *GDALRasterIO;
